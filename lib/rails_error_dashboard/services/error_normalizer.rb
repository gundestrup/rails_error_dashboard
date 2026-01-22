# frozen_string_literal: true

module RailsErrorDashboard
  module Services
    # Smart error message normalization for better error grouping
    #
    # Replaces dynamic values (IDs, UUIDs, timestamps, etc.) with placeholders
    # while preserving semantic meaning. This improves error deduplication accuracy
    # compared to naive "replace all numbers" approach.
    #
    # @example
    #   ErrorNormalizer.normalize("User 123 not found")
    #   # => "User :id not found"
    #
    #   ErrorNormalizer.normalize("Expected 2 arguments, got 5")
    #   # => "Expected 2 arguments, got 5" (preserves meaningful numbers)
    #
    class ErrorNormalizer
      # Patterns for smart normalization
      # Order matters: more specific patterns should come first
      PATTERNS = {
        # UUIDs (e.g., "550e8400-e29b-41d4-a716-446655440000")
        uuid: /\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i,

        # Memory addresses (e.g., "<User:0x00007f8b1a2b3c4d>", "0x00007f8b1a2b3c4d")
        # MUST come before hash_id to match memory addresses first
        memory_address: /#?<[^>]+:0x[0-9a-f]+>/i,
        hex_address: /\b0x[0-9a-f]{8,16}\b/i,

        # Timestamps (ISO8601 and common formats)
        # Remove timezone offset separately to avoid leaving it behind
        timestamp_iso: /\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?/,
        timestamp_unix: /\btimestamp[:\s]+\d{10,13}\b/i,

        # Tokens and API keys (long alphanumeric strings)
        # MUST come before large_number to match long tokens first
        token: /\b[a-z0-9]{32,}\b/i,

        # Object IDs and database IDs (e.g., "User #123", "id: 456", "ID=789")
        # MUST come before hash_id to match specific ID patterns first
        object_id: /(?:#|(?:id|ID)(?:\s*[=:#]\s*|\s+))\d+\b/,
        # Ruby-style object references (e.g., "User:123", "#<User:123>")
        hash_id: /#?<?[A-Z]\w*:\d+>?/,

        # File paths with dynamic components (but check for UUIDs in path first)
        # More specific pattern: match /tmp/ followed by UUID-like or hash-like segment
        temp_path: %r{/(?:tmp|var/tmp|private/tmp)/(?:[a-z0-9_-]+/)*[a-z0-9_-]+(?:\.[a-z0-9]+)?},

        # Numbered URL paths - MUST come before large_number
        # Capture the leading slash with the number, and optional trailing slash
        numbered_path: %r{/\d+(?=/|$)}, # e.g., "/api/users/123/posts" → "/api/users:numbered_path/posts"

        # Email addresses (preserve domain, replace local part)
        email: /\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b/i,

        # IP addresses
        ipv4: /\b(?:\d{1,3}\.){3}\d{1,3}\b/,
        ipv6: /\b(?:[0-9a-f]{1,4}:){7}[0-9a-f]{1,4}\b/i,

        # Hexadecimal values (but not in memory addresses - already handled)
        hex_value: /\b0x[0-9a-f]+\b/i,

        # Standalone large numbers (likely IDs, but preserve small numbers < 1000)
        # MUST come last to avoid matching parts of other patterns
        large_number: /\b\d{4,}\b/
      }.freeze

      class << self
        # Normalize an error message by replacing dynamic values with placeholders
        #
        # @param message [String] the error message to normalize
        # @return [String] the normalized message
        def normalize(message)
          return "" if message.nil?
          return message if message.strip.empty? # Preserve whitespace-only strings

          normalized = message.dup

          # Apply each pattern in order
          PATTERNS.each do |type, pattern|
            normalized.gsub!(pattern, ":#{type}")
          end

          # Clean up leftover timezone offsets that weren't caught by timestamp pattern
          normalized.gsub!(/\s+[+-]\d{2}:\d{2}$/, "")

          normalized
        end

        # Extract significant backtrace frames, skipping gem/vendor code
        #
        # @param backtrace [String] the full backtrace string
        # @param count [Integer] number of frames to extract (default: 3)
        # @return [String, nil] the significant frames joined with "|"
        def extract_significant_frames(backtrace, count: 3)
          return nil if backtrace.blank?

          frames = backtrace.split("\n")
            .map(&:strip)
            .reject { |line| gem_or_vendor_code?(line) }
            .reject { |line| ruby_stdlib_code?(line) }
            .first(count)
            .map { |line| extract_file_and_method(line) }
            .compact

          frames.empty? ? nil : frames.join("|")
        end

        private

        # Check if a backtrace line is from gem/vendor code
        def gem_or_vendor_code?(line)
          line.include?("vendor/bundle") ||
            line.include?("gems/") ||
            line.include?(".gem/ruby")
        end

        # Check if a backtrace line is from Ruby standard library
        def ruby_stdlib_code?(line)
          line.include?("/ruby/") ||
            line.include?("/lib/ruby/") ||
            line.match?(%r{ruby-\d+\.\d+\.\d+/lib})
        end

        # Extract file path and method name from a backtrace line
        # Example: "/app/models/user.rb:10:in `name'" => "/app/models/user.rb:name"
        def extract_file_and_method(line)
          # Match pattern: file.rb:line:in `method'
          match = line.match(%r{^(.+\.rb):(\d+)(?::in `(.+)')?})
          return nil unless match

          file = match[1]
          method = match[3]

          # Remove absolute path prefix for consistency
          file = file.sub(%r{.*/(?=app/)}, "")

          method ? "#{file}:#{method}" : file
        end
      end
    end
  end
end
