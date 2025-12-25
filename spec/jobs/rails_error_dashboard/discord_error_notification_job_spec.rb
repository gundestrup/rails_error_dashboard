# frozen_string_literal: true

require "rails_helper"

RSpec.describe RailsErrorDashboard::DiscordErrorNotificationJob, type: :job do
  let(:error_log) { create(:error_log) }
  let(:webhook_url) { "https://discord.com/api/webhooks/123456789/test_webhook" }

  before do
    RailsErrorDashboard.configuration.discord_webhook_url = webhook_url
  end

  describe "#perform" do
    context "when error log exists" do
      it "sends Discord notification" do
        stub_request(:post, webhook_url)
          .with(
            body: hash_including(embeds: array_including(hash_including(title: /New Error/))),
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 204)

        described_class.new.perform(error_log.id)

        expect(WebMock).to have_requested(:post, webhook_url).once
      end

      it "includes error type in embed title" do
        stub_request(:post, webhook_url).to_return(status: 204)

        described_class.new.perform(error_log.id)

        expect(WebMock).to have_requested(:post, webhook_url).with { |req|
          body = JSON.parse(req.body)
          body["embeds"].first["title"].include?(error_log.error_type)
        }
      end

      it "includes error icon in embed title" do
        stub_request(:post, webhook_url).to_return(status: 204)

        described_class.new.perform(error_log.id)

        expect(WebMock).to have_requested(:post, webhook_url).with { |req|
          body = JSON.parse(req.body)
          body["embeds"].first["title"].include?("🚨")
        }
      end

      it "includes error message in description" do
        stub_request(:post, webhook_url).to_return(status: 204)

        described_class.new.perform(error_log.id)

        expect(WebMock).to have_requested(:post, webhook_url).with { |req|
          body = JSON.parse(req.body)
          body["embeds"].first["description"] == error_log.message
        }
      end

      it "includes platform field" do
        error_log.update(platform: "iOS")
        stub_request(:post, webhook_url).to_return(status: 204)

        described_class.new.perform(error_log.id)

        expect(WebMock).to have_requested(:post, webhook_url).with { |req|
          body = JSON.parse(req.body)
          platform_field = body["embeds"].first["fields"].find { |f| f["name"] == "Platform" }
          platform_field["value"] == "iOS" && platform_field["inline"] == true
        }
      end

      it "includes occurrence count field" do
        error_log.update(occurrence_count: 42)
        stub_request(:post, webhook_url).to_return(status: 204)

        described_class.new.perform(error_log.id)

        expect(WebMock).to have_requested(:post, webhook_url).with { |req|
          body = JSON.parse(req.body)
          count_field = body["embeds"].first["fields"].find { |f| f["name"] == "Occurrences" }
          count_field["value"] == "42"
        }
      end

      it "includes controller field" do
        error_log.update(controller_name: "UsersController")
        stub_request(:post, webhook_url).to_return(status: 204)

        described_class.new.perform(error_log.id)

        expect(WebMock).to have_requested(:post, webhook_url).with { |req|
          body = JSON.parse(req.body)
          controller_field = body["embeds"].first["fields"].find { |f| f["name"] == "Controller" }
          controller_field["value"] == "UsersController"
        }
      end

      it "includes action field" do
        error_log.update(action_name: "show")
        stub_request(:post, webhook_url).to_return(status: 204)

        described_class.new.perform(error_log.id)

        expect(WebMock).to have_requested(:post, webhook_url).with { |req|
          body = JSON.parse(req.body)
          action_field = body["embeds"].first["fields"].find { |f| f["name"] == "Action" }
          action_field["value"] == "show"
        }
      end

      it "includes first seen timestamp" do
        stub_request(:post, webhook_url).to_return(status: 204)

        described_class.new.perform(error_log.id)

        expect(WebMock).to have_requested(:post, webhook_url).with { |req|
          body = JSON.parse(req.body)
          time_field = body["embeds"].first["fields"].find { |f| f["name"] == "First Seen" }
          time_field["value"].present?
        }
      end

      it "includes location from backtrace" do
        error_log.update(backtrace: "app/controllers/users_controller.rb:42:in `show`")
        stub_request(:post, webhook_url).to_return(status: 204)

        described_class.new.perform(error_log.id)

        expect(WebMock).to have_requested(:post, webhook_url).with { |req|
          body = JSON.parse(req.body)
          location_field = body["embeds"].first["fields"].find { |f| f["name"] == "Location" }
          location_field["value"].include?("users_controller.rb")
        }
      end

      it "includes footer" do
        stub_request(:post, webhook_url).to_return(status: 204)

        described_class.new.perform(error_log.id)

        expect(WebMock).to have_requested(:post, webhook_url).with { |req|
          body = JSON.parse(req.body)
          body["embeds"].first["footer"]["text"] == "Rails Error Dashboard"
        }
      end

      it "includes ISO8601 timestamp" do
        stub_request(:post, webhook_url).to_return(status: 204)

        described_class.new.perform(error_log.id)

        expect(WebMock).to have_requested(:post, webhook_url).with { |req|
          body = JSON.parse(req.body)
          timestamp = body["embeds"].first["timestamp"]
          timestamp.present? && timestamp.match?(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
        }
      end

      context "when message is very long" do
        let(:long_message) { "Error: " + ("x" * 300) }
        let(:error_log) { create(:error_log, message: long_message) }

        it "truncates the message" do
          stub_request(:post, webhook_url).to_return(status: 204)

          described_class.new.perform(error_log.id)

          expect(WebMock).to have_requested(:post, webhook_url).with { |req|
            body = JSON.parse(req.body)
            description = body["embeds"].first["description"]
            expect(description.length).to be <= 203 # 200 + "..."
            expect(description).to end_with("...")
          }
        end
      end

      context "when backtrace is very long" do
        let(:long_backtrace_line) { "app/controllers/very/deep/nested/path/" + ("x" * 200) + ".rb:42:in `method`" }
        let(:error_log) { create(:error_log, backtrace: long_backtrace_line) }

        it "truncates the backtrace location" do
          stub_request(:post, webhook_url).to_return(status: 204)

          described_class.new.perform(error_log.id)

          expect(WebMock).to have_requested(:post, webhook_url).with { |req|
            body = JSON.parse(req.body)
            location_field = body["embeds"].first["fields"].find { |f| f["name"] == "Location" }
            expect(location_field["value"].length).to be <= 103 # 100 + "..."
            expect(location_field["value"]).to end_with("...")
          }
        end
      end

      context "with multiline backtrace" do
        let(:backtrace) do
          [
            "app/controllers/users_controller.rb:42:in `show`",
            "app/middleware/auth.rb:10:in `call`",
            "lib/framework/base.rb:5:in `process`"
          ].join("\n")
        end
        let(:error_log) { create(:error_log, backtrace: backtrace) }

        it "extracts only first line" do
          stub_request(:post, webhook_url).to_return(status: 204)

          described_class.new.perform(error_log.id)

          expect(WebMock).to have_requested(:post, webhook_url).with { |req|
            body = JSON.parse(req.body)
            location_field = body["embeds"].first["fields"].find { |f| f["name"] == "Location" }
            location = location_field["value"]
            expect(location).to include("users_controller.rb")
            expect(location).not_to include("auth.rb")
          }
        end
      end

      context "with nil or missing fields" do
        let(:error_log) do
          # Note: platform defaults to "API" via model callback
          # first_seen_at defaults to Time.current via model callback
          create(:error_log,
            controller_name: nil,
            action_name: nil,
            backtrace: nil
          )
        end

        it "handles nil controller gracefully" do
          stub_request(:post, webhook_url).to_return(status: 204)

          described_class.new.perform(error_log.id)

          expect(WebMock).to have_requested(:post, webhook_url).with { |req|
            body = JSON.parse(req.body)
            controller_field = body["embeds"].first["fields"].find { |f| f["name"] == "Controller" }
            controller_field["value"] == "N/A"
          }
        end

        it "handles nil action gracefully" do
          stub_request(:post, webhook_url).to_return(status: 204)

          described_class.new.perform(error_log.id)

          expect(WebMock).to have_requested(:post, webhook_url).with { |req|
            body = JSON.parse(req.body)
            action_field = body["embeds"].first["fields"].find { |f| f["name"] == "Action" }
            action_field["value"] == "N/A"
          }
        end

        it "handles nil backtrace gracefully" do
          stub_request(:post, webhook_url).to_return(status: 204)

          described_class.new.perform(error_log.id)

          expect(WebMock).to have_requested(:post, webhook_url).with { |req|
            body = JSON.parse(req.body)
            location_field = body["embeds"].first["fields"].find { |f| f["name"] == "Location" }
            location_field["value"] == "N/A"
          }
        end
      end
    end

    context "when error log does not exist" do
      it "handles the exception gracefully" do
        stub_request(:post, webhook_url)

        allow(Rails.logger).to receive(:error)

        expect {
          described_class.new.perform(999999)
        }.not_to raise_error

        expect(WebMock).not_to have_requested(:post, webhook_url)
        expect(Rails.logger).to have_received(:error).with(/Failed to send Discord notification/)
      end
    end

    context "when webhook URL is not configured" do
      before do
        RailsErrorDashboard.configuration.discord_webhook_url = nil
      end

      it "does not send notification" do
        stub_request(:post, webhook_url)

        described_class.new.perform(error_log.id)

        expect(WebMock).not_to have_requested(:post, webhook_url)
      end
    end

    context "when webhook URL is empty string" do
      before do
        RailsErrorDashboard.configuration.discord_webhook_url = ""
      end

      it "does not send notification" do
        stub_request(:post, webhook_url)

        described_class.new.perform(error_log.id)

        expect(WebMock).not_to have_requested(:post, webhook_url)
      end
    end

    context "when Discord API returns error" do
      it "logs the error" do
        stub_request(:post, webhook_url).to_raise(StandardError.new("API Error"))

        allow(Rails.logger).to receive(:error)

        described_class.new.perform(error_log.id)

        expect(Rails.logger).to have_received(:error).with(/Failed to send Discord notification/)
      end
    end

    context "when network error occurs" do
      it "handles the exception gracefully" do
        stub_request(:post, webhook_url).to_raise(StandardError.new("Network error"))

        allow(Rails.logger).to receive(:error)

        expect {
          described_class.new.perform(error_log.id)
        }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(/Failed to send Discord notification/)
      end
    end
  end

  describe "#severity_color" do
    let(:job) { described_class.new }

    it "returns red for critical severity" do
      critical_error = create(:error_log, error_type: "SecurityError")
      expect(job.send(:severity_color, critical_error)).to eq(16711680)
    end

    it "returns orange for high severity" do
      high_error = create(:error_log, error_type: "ArgumentError")
      expect(job.send(:severity_color, high_error)).to eq(16744192)
    end

    it "returns yellow for medium severity" do
      medium_error = create(:error_log, error_type: "ActiveRecord::RecordInvalid")
      expect(job.send(:severity_color, medium_error)).to eq(16776960)
    end

    it "returns gray for unknown severity" do
      low_error = create(:error_log, error_type: "StandardError")
      expect(job.send(:severity_color, low_error)).to eq(8421504)
    end
  end

  describe "#truncate_message" do
    let(:job) { described_class.new }

    it "returns message as-is if shorter than limit" do
      message = "Short message"
      expect(job.send(:truncate_message, message)).to eq(message)
    end

    it "truncates message if longer than default limit" do
      message = "x" * 300
      result = job.send(:truncate_message, message)
      expect(result.length).to eq(203) # 200 + "..."
      expect(result).to end_with("...")
    end

    it "respects custom length parameter" do
      message = "x" * 300
      result = job.send(:truncate_message, message, 50)
      expect(result.length).to eq(53) # 50 + "..."
    end

    it "handles nil message" do
      expect(job.send(:truncate_message, nil)).to eq("")
    end
  end

  describe "#format_time" do
    let(:job) { described_class.new }

    it "formats time in UTC" do
      time = Time.utc(2024, 12, 24, 15, 30, 45)
      expect(job.send(:format_time, time)).to eq("2024-12-24 15:30:45 UTC")
    end

    it "handles nil time" do
      expect(job.send(:format_time, nil)).to eq("N/A")
    end
  end

  describe "#extract_first_backtrace_line" do
    let(:job) { described_class.new }

    it "extracts first line from string backtrace" do
      backtrace = "app/controllers/users_controller.rb:42:in `show`\napp/middleware/auth.rb:10"
      result = job.send(:extract_first_backtrace_line, backtrace)
      expect(result).to eq("app/controllers/users_controller.rb:42:in `show`")
    end

    it "extracts first line from array backtrace" do
      backtrace = ["app/controllers/users_controller.rb:42:in `show`", "app/middleware/auth.rb:10"]
      result = job.send(:extract_first_backtrace_line, backtrace)
      expect(result).to eq("app/controllers/users_controller.rb:42:in `show`")
    end

    it "truncates very long backtrace lines" do
      backtrace = "app/" + ("x" * 200) + ".rb:42"
      result = job.send(:extract_first_backtrace_line, backtrace)
      expect(result.length).to eq(103) # 100 + "..."
      expect(result).to end_with("...")
    end

    it "handles nil backtrace" do
      expect(job.send(:extract_first_backtrace_line, nil)).to eq("N/A")
    end

    it "handles empty backtrace" do
      expect(job.send(:extract_first_backtrace_line, "")).to eq("N/A")
      expect(job.send(:extract_first_backtrace_line, [])).to eq("N/A")
    end
  end

  describe "job queue" do
    it "is enqueued to default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
