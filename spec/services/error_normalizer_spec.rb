# frozen_string_literal: true

require "rails_helper"

RSpec.describe RailsErrorDashboard::Services::ErrorNormalizer do
  describe ".normalize" do
    context "with blank input" do
      it "returns empty string for nil" do
        expect(described_class.normalize(nil)).to eq("")
      end

      it "returns empty string for empty string" do
        expect(described_class.normalize("")).to eq("")
      end
    end

    context "with UUID patterns" do
      it "normalizes lowercase UUID" do
        message = "Record 550e8400-e29b-41d4-a716-446655440000 not found"
        expect(described_class.normalize(message)).to eq("Record :uuid not found")
      end

      it "normalizes uppercase UUID" do
        message = "Record 550E8400-E29B-41D4-A716-446655440000 not found"
        expect(described_class.normalize(message)).to eq("Record :uuid not found")
      end

      it "normalizes multiple UUIDs" do
        message = "Conflict between 550e8400-e29b-41d4-a716-446655440000 and abc12345-6789-4def-0123-456789abcdef"
        expect(described_class.normalize(message)).to eq("Conflict between :uuid and :uuid")
      end
    end

    context "with timestamp patterns" do
      it "normalizes ISO8601 timestamp" do
        message = "Timeout at 2026-01-22T10:30:45Z"
        expect(described_class.normalize(message)).to eq("Timeout at :timestamp_iso")
      end

      it "normalizes timestamp with timezone" do
        message = "Error at 2026-01-22 10:30:45 +00:00"
        expect(described_class.normalize(message)).to eq("Error at :timestamp_iso")
      end

      it "normalizes timestamp with milliseconds" do
        message = "Occurred at 2026-01-22T10:30:45.123Z"
        expect(described_class.normalize(message)).to eq("Occurred at :timestamp_iso")
      end

      it "normalizes unix timestamp" do
        message = "timestamp: 1737543045"
        expect(described_class.normalize(message)).to eq(":timestamp_unix")
      end
    end

    context "with object ID patterns" do
      it "normalizes 'User #123' style" do
        message = "User #123 not found"
        expect(described_class.normalize(message)).to eq("User :object_id not found")
      end

      it "normalizes 'id: 456' style" do
        message = "Record id: 456 is invalid"
        expect(described_class.normalize(message)).to eq("Record :object_id is invalid")
      end

      it "normalizes 'ID=789' style" do
        message = "Failed for ID=789"
        expect(described_class.normalize(message)).to eq("Failed for :object_id")
      end

      it "normalizes hash-style object" do
        message = "Error in #<User:123>"
        expect(described_class.normalize(message)).to eq("Error in :hash_id")
      end
    end

    context "with memory addresses" do
      it "normalizes Ruby object memory address" do
        message = "undefined method for #<User:0x00007f8b1a2b3c4d>"
        expect(described_class.normalize(message)).to eq("undefined method for :memory_address")
      end

      it "normalizes standalone hex address" do
        message = "Segfault at 0x00007f8b1a2b3c4d"
        expect(described_class.normalize(message)).to eq("Segfault at :hex_address")
      end
    end

    context "with file paths" do
      it "normalizes temp file paths" do
        message = "File not found: /tmp/uploads/abc123/file.txt"
        expect(described_class.normalize(message)).to eq("File not found: :temp_path")
      end

      it "normalizes var/tmp paths" do
        message = "Failed to load /var/tmp/cache/data.json"
        expect(described_class.normalize(message)).to eq("Failed to load :temp_path")
      end

      it "normalizes private/tmp paths" do
        message = "Error reading /private/tmp/session/xyz"
        expect(described_class.normalize(message)).to eq("Error reading :temp_path")
      end

      it "normalizes numbered URL paths" do
        message = "GET /api/users/123/posts failed"
        expect(described_class.normalize(message)).to eq("GET /api/users:numbered_path/posts failed")
      end
    end

    context "with email addresses" do
      it "normalizes email addresses" do
        message = "Email invalid: user@example.com"
        expect(described_class.normalize(message)).to eq("Email invalid: :email")
      end

      it "normalizes email with + sign" do
        message = "Duplicate email: user+test@example.com"
        expect(described_class.normalize(message)).to eq("Duplicate email: :email")
      end
    end

    context "with IP addresses" do
      it "normalizes IPv4 addresses" do
        message = "Request from 192.168.1.100 blocked"
        expect(described_class.normalize(message)).to eq("Request from :ipv4 blocked")
      end

      it "normalizes IPv6 addresses" do
        message = "Connection from 2001:0db8:85a3:0000:0000:8a2e:0370:7334"
        expect(described_class.normalize(message)).to eq("Connection from :ipv6")
      end
    end

    context "with tokens and API keys" do
      it "normalizes long alphanumeric tokens" do
        message = "Invalid token: abc123def456ghi789jkl012mno345pqr678"
        expect(described_class.normalize(message)).to eq("Invalid token: :token")
      end
    end

    context "with large numbers" do
      it "normalizes large numbers (IDs)" do
        message = "Record 123456 not found"
        expect(described_class.normalize(message)).to eq("Record :large_number not found")
      end

      it "preserves small numbers (meaningful values)" do
        message = "Expected 2 arguments, got 5"
        # Small numbers < 1000 are preserved
        expect(described_class.normalize(message)).to eq("Expected 2 arguments, got 5")
      end

      it "preserves meaningful small numbers in context" do
        message = "Array index 42 out of bounds"
        expect(described_class.normalize(message)).to eq("Array index 42 out of bounds")
      end
    end

    context "with hex values" do
      it "normalizes standalone hex values" do
        message = "Invalid color: 0x1a2b3c"
        expect(described_class.normalize(message)).to eq("Invalid color: :hex_value")
      end
    end

    context "with real-world error messages" do
      it "normalizes NoMethodError with object ID" do
        message = "undefined method `name' for #<User:0x00007f8b1a2b3c4d>"
        result = described_class.normalize(message)
        expect(result).to eq("undefined method `name' for :memory_address")
      end

      it "normalizes ActiveRecord::RecordNotFound" do
        message = "Couldn't find User with 'id'=123456"
        result = described_class.normalize(message)
        expect(result).to eq("Couldn't find User with 'id'=:large_number")
      end

      it "normalizes Timeout::Error with timestamp" do
        message = "Request timeout at 2026-01-22T10:30:45Z for GET /api/users/456"
        result = described_class.normalize(message)
        # numbered_path matches /456 at end of URL path
        expect(result).to eq("Request timeout at :timestamp_iso for GET /api/users:numbered_path")
      end

      it "normalizes validation error with multiple IDs" do
        message = "Duplicate entry for User #123 and Post #456"
        result = described_class.normalize(message)
        expect(result).to eq("Duplicate entry for User :object_id and Post :object_id")
      end

      it "normalizes API error with UUID" do
        message = "Invalid transaction: 550e8400-e29b-41d4-a716-446655440000"
        result = described_class.normalize(message)
        expect(result).to eq("Invalid transaction: :uuid")
      end

      it "preserves semantic meaning in argument errors" do
        message = "wrong number of arguments (given 3, expected 1..2)"
        result = described_class.normalize(message)
        # Small numbers are preserved
        expect(result).to eq("wrong number of arguments (given 3, expected 1..2)")
      end
    end

    context "with complex messages containing multiple patterns" do
      it "normalizes multiple different patterns" do
        message = "User #123 from 192.168.1.100 uploaded file to /tmp/uploads/550e8400-e29b-41d4-a716-446655440000 at 2026-01-22T10:30:45Z"
        result = described_class.normalize(message)
        # temp_path matches the /tmp/uploads/uuid part before UUID can be extracted separately
        expect(result).to eq("User :object_id from :ipv4 uploaded file to :temp_path/:uuid at :timestamp_iso")
      end
    end

    context "edge cases" do
      it "handles empty message" do
        expect(described_class.normalize("")).to eq("")
      end

      it "handles message with only whitespace" do
        expect(described_class.normalize("   ")).to eq("   ")
      end

      it "handles message with no patterns to replace" do
        message = "Something went wrong"
        expect(described_class.normalize(message)).to eq("Something went wrong")
      end

      it "handles very long message" do
        message = "Error: " + ("x" * 10000) + " for User #123"
        result = described_class.normalize(message)
        expect(result).to include("Error:")
        expect(result).to end_with(" for User :object_id")
      end
    end
  end

  describe ".extract_significant_frames" do
    context "with blank input" do
      it "returns nil for nil backtrace" do
        expect(described_class.extract_significant_frames(nil)).to be_nil
      end

      it "returns nil for empty backtrace" do
        expect(described_class.extract_significant_frames("")).to be_nil
      end
    end

    context "with application code" do
      it "extracts significant frames from backtrace" do
        backtrace = <<~BACKTRACE
          app/models/user.rb:42:in `name'
          app/controllers/users_controller.rb:15:in `show'
          app/controllers/application_controller.rb:5:in `authenticate'
        BACKTRACE

        result = described_class.extract_significant_frames(backtrace, count: 3)
        expect(result).to eq("app/models/user.rb:name|app/controllers/users_controller.rb:show|app/controllers/application_controller.rb:authenticate")
      end

      it "limits to specified count" do
        backtrace = <<~BACKTRACE
          app/models/user.rb:42:in `name'
          app/controllers/users_controller.rb:15:in `show'
          app/controllers/application_controller.rb:5:in `authenticate'
          app/lib/helper.rb:10:in `format'
        BACKTRACE

        result = described_class.extract_significant_frames(backtrace, count: 2)
        expect(result).to eq("app/models/user.rb:name|app/controllers/users_controller.rb:show")
      end
    end

    context "filtering out gem and vendor code" do
      it "skips vendor/bundle frames" do
        backtrace = <<~BACKTRACE
          app/models/user.rb:42:in `name'
          vendor/bundle/ruby/3.2.0/gems/activerecord-7.0.0/lib/active_record/base.rb:100
          app/controllers/users_controller.rb:15:in `show'
        BACKTRACE

        result = described_class.extract_significant_frames(backtrace, count: 3)
        expect(result).to eq("app/models/user.rb:name|app/controllers/users_controller.rb:show")
      end

      it "skips gem directory frames" do
        backtrace = <<~BACKTRACE
          app/models/user.rb:42:in `name'
          /usr/local/lib/gems/ruby/3.2.0/gems/rack-2.2.3/lib/rack.rb:50
          app/controllers/users_controller.rb:15:in `show'
        BACKTRACE

        result = described_class.extract_significant_frames(backtrace, count: 3)
        expect(result).to eq("app/models/user.rb:name|app/controllers/users_controller.rb:show")
      end

      it "skips Ruby stdlib frames" do
        backtrace = <<~BACKTRACE
          app/models/user.rb:42:in `name'
          /usr/local/lib/ruby/3.2.0/set.rb:200:in `add'
          app/controllers/users_controller.rb:15:in `show'
        BACKTRACE

        result = described_class.extract_significant_frames(backtrace, count: 3)
        expect(result).to eq("app/models/user.rb:name|app/controllers/users_controller.rb:show")
      end
    end

    context "with absolute paths" do
      it "removes absolute path prefix before app/" do
        backtrace = <<~BACKTRACE
          /Users/developer/projects/myapp/app/models/user.rb:42:in `name'
          /Users/developer/projects/myapp/app/controllers/users_controller.rb:15:in `show'
        BACKTRACE

        result = described_class.extract_significant_frames(backtrace, count: 2)
        expect(result).to eq("app/models/user.rb:name|app/controllers/users_controller.rb:show")
      end
    end

    context "with frames missing method names" do
      it "handles frames without method names" do
        backtrace = <<~BACKTRACE
          app/models/user.rb:42
          app/controllers/users_controller.rb:15:in `show'
        BACKTRACE

        result = described_class.extract_significant_frames(backtrace, count: 2)
        expect(result).to eq("app/models/user.rb|app/controllers/users_controller.rb:show")
      end
    end

    context "edge cases" do
      it "returns nil when all frames are filtered out" do
        backtrace = <<~BACKTRACE
          vendor/bundle/ruby/3.2.0/gems/activerecord-7.0.0/lib/active_record/base.rb:100
          /usr/local/lib/ruby/3.2.0/set.rb:200:in `add'
        BACKTRACE

        result = described_class.extract_significant_frames(backtrace, count: 3)
        expect(result).to be_nil
      end

      it "handles malformed backtrace lines" do
        backtrace = <<~BACKTRACE
          app/models/user.rb:42:in `name'
          invalid line format
          app/controllers/users_controller.rb:15:in `show'
        BACKTRACE

        result = described_class.extract_significant_frames(backtrace, count: 3)
        # Should skip malformed line
        expect(result).to eq("app/models/user.rb:name|app/controllers/users_controller.rb:show")
      end

      it "handles single-line backtrace" do
        backtrace = "app/models/user.rb:42:in `name'"
        result = described_class.extract_significant_frames(backtrace, count: 3)
        expect(result).to eq("app/models/user.rb:name")
      end
    end
  end
end
