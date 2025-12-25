# frozen_string_literal: true

require "rails_helper"

RSpec.describe RailsErrorDashboard::AsyncErrorLoggingJob, type: :job do
  describe "#perform" do
    let(:exception_data) do
      {
        class_name: "StandardError",
        message: "Test async error",
        backtrace: [ "app/controllers/test_controller.rb:10:in `index'" ]
      }
    end
    let(:context) { { user_id: 1, platform: "API" } }

    it "creates an error log" do
      expect {
        described_class.new.perform(exception_data, context)
      }.to change(RailsErrorDashboard::ErrorLog, :count).by(1)
    end

    it "reconstructs the exception with correct class" do
      described_class.new.perform(exception_data, context)
      error_log = RailsErrorDashboard::ErrorLog.last

      expect(error_log.error_type).to eq("StandardError")
    end

    it "reconstructs the exception with correct message" do
      described_class.new.perform(exception_data, context)
      error_log = RailsErrorDashboard::ErrorLog.last

      expect(error_log.message).to eq("Test async error")
    end

    it "reconstructs the exception with correct backtrace" do
      described_class.new.perform(exception_data, context)
      error_log = RailsErrorDashboard::ErrorLog.last

      expect(error_log.backtrace).to include("app/controllers/test_controller.rb:10:in `index'")
    end

    it "preserves context data" do
      described_class.new.perform(exception_data, context)
      error_log = RailsErrorDashboard::ErrorLog.last

      expect(error_log.user_id).to eq(1)
      expect(error_log.platform).to eq("API")
    end

    context "with different exception types" do
      it "handles ArgumentError" do
        data = exception_data.merge(class_name: "ArgumentError")

        described_class.new.perform(data, context)
        error_log = RailsErrorDashboard::ErrorLog.last

        expect(error_log.error_type).to eq("ArgumentError")
      end

      it "handles SecurityError" do
        data = exception_data.merge(class_name: "SecurityError")

        described_class.new.perform(data, context)
        error_log = RailsErrorDashboard::ErrorLog.last

        expect(error_log.error_type).to eq("SecurityError")
        expect(error_log.critical?).to be true
      end
    end

    context "when exception class doesn't exist" do
      it "falls back to StandardError" do
        data = exception_data.merge(class_name: "NonExistentError")

        described_class.new.perform(data, context)
        error_log = RailsErrorDashboard::ErrorLog.last

        expect(error_log.error_type).to eq("StandardError")
      end

      it "still logs the original message" do
        data = exception_data.merge(
          class_name: "NonExistentError",
          message: "Original error message"
        )

        described_class.new.perform(data, context)
        error_log = RailsErrorDashboard::ErrorLog.last

        expect(error_log.message).to eq("Original error message")
      end
    end

    context "when backtrace is nil" do
      it "handles missing backtrace gracefully" do
        data = exception_data.merge(backtrace: nil)

        expect {
          described_class.new.perform(data, context)
        }.to change(RailsErrorDashboard::ErrorLog, :count).by(1)
      end
    end

    context "when job execution fails" do
      it "logs the error and doesn't raise" do
        # Mock the instance method, not the class method
        allow_any_instance_of(RailsErrorDashboard::Commands::LogError).to receive(:call).and_raise("Job error")

        expect(Rails.logger).to receive(:error).with(/AsyncErrorLoggingJob failed/)
        expect(Rails.logger).to receive(:error).with(/Backtrace:/)

        expect {
          described_class.new.perform(exception_data, context)
        }.not_to raise_error
      end
    end
  end

  describe "queue" do
    it "is enqueued to default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
