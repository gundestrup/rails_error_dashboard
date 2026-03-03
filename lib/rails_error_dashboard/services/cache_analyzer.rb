# frozen_string_literal: true

module RailsErrorDashboard
  module Services
    # Pure algorithm: Analyze cache breadcrumbs at display time
    #
    # Operates on already-captured breadcrumb data — zero runtime cost.
    # Called at display time only. Similar pattern to NplusOneDetector.
    #
    # @example
    #   RailsErrorDashboard::Services::CacheAnalyzer.call(breadcrumbs)
    #   # => { reads: 5, writes: 2, hits: 3, misses: 1, unknown: 1,
    #   #      hit_rate: 75.0, total_duration_ms: 12.5,
    #   #      slowest: { message: "cache read: users/1", duration_ms: 5.2 } }
    class CacheAnalyzer
      # @param breadcrumbs [Array<Hash>] Parsed breadcrumb array
      # @return [Hash, nil] Cache analysis summary, or nil if no cache breadcrumbs
      def self.call(breadcrumbs)
        return nil unless breadcrumbs.is_a?(Array)

        cache_crumbs = breadcrumbs.select { |c| c["c"] == "cache" }
        return nil if cache_crumbs.empty?

        reads = 0
        writes = 0
        hits = 0
        misses = 0
        unknown = 0
        total_duration = 0.0
        slowest = nil

        cache_crumbs.each do |crumb|
          message = crumb["m"].to_s
          duration = crumb["d"].to_f

          if message.start_with?("cache read:")
            reads += 1
            hit_status = crumb.dig("meta", "hit")
            if hit_status.nil?
              unknown += 1
            elsif hit_status == true || hit_status == "true"
              hits += 1
            else
              misses += 1
            end
          elsif message.start_with?("cache write:")
            writes += 1
          end

          total_duration += duration

          if slowest.nil? || duration > slowest[:duration_ms]
            slowest = { message: message, duration_ms: duration }
          end
        end

        # Only calculate hit_rate if we have read breadcrumbs with known hit status
        known_reads = hits + misses
        hit_rate = known_reads > 0 ? (hits.to_f / known_reads * 100).round(1) : nil

        {
          reads: reads,
          writes: writes,
          hits: hits,
          misses: misses,
          unknown: unknown,
          hit_rate: hit_rate,
          total_duration_ms: total_duration.round(1),
          slowest: slowest
        }
      rescue => e
        nil
      end
    end
  end
end
