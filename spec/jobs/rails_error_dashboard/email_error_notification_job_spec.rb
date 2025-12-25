# frozen_string_literal: true

require "rails_helper"

RSpec.describe RailsErrorDashboard::EmailErrorNotificationJob, type: :job do
  let(:error_log) { create(:error_log) }
  let(:recipients) { [ "dev@example.com", "admin@example.com" ] }

  before do
    RailsErrorDashboard.configuration.notification_email_recipients = recipients
    RailsErrorDashboard.configuration.notification_email_from = "errors@example.com"
    RailsErrorDashboard.configuration.dashboard_base_url = "https://example.com"
  end

  describe "#perform" do
    context "when error log exists" do
      it "sends email notification" do
        expect {
          described_class.new.perform(error_log.id)
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "sends to configured recipients" do
        described_class.new.perform(error_log.id)

        email = ActionMailer::Base.deliveries.last
        expect(email.to).to match_array(recipients)
      end

      it "includes error type in subject" do
        described_class.new.perform(error_log.id)

        email = ActionMailer::Base.deliveries.last
        expect(email.subject).to include(error_log.error_type)
      end

      it "includes error icon in subject" do
        described_class.new.perform(error_log.id)

        email = ActionMailer::Base.deliveries.last
        expect(email.subject).to include("🚨")
      end

      it "truncates long messages in subject" do
        long_message = "Error: " + ("x" * 100)
        error_log.update(message: long_message)

        described_class.new.perform(error_log.id)

        email = ActionMailer::Base.deliveries.last
        subject_message = email.subject.split(": ").last
        expect(subject_message.length).to be <= 53 # 50 chars + "..."
        expect(subject_message).to end_with("...")
      end

      it "includes error type in HTML body" do
        described_class.new.perform(error_log.id)

        email = ActionMailer::Base.deliveries.last
        expect(email.html_part.body.to_s).to include(error_log.error_type)
      end

      it "includes error message in HTML body" do
        described_class.new.perform(error_log.id)

        email = ActionMailer::Base.deliveries.last
        expect(email.html_part.body.to_s).to include(error_log.message)
      end

      it "includes platform badge when present" do
        error_log.update(platform: "iOS")

        described_class.new.perform(error_log.id)

        email = ActionMailer::Base.deliveries.last
        html_body = email.html_part.body.to_s
        expect(html_body).to include("iOS")
        expect(html_body).to include("badge-ios")
      end

      it "includes dashboard URL link" do
        described_class.new.perform(error_log.id)

        email = ActionMailer::Base.deliveries.last
        expected_url = "https://example.com/error_dashboard/errors/#{error_log.id}"
        expect(email.html_part.body.to_s).to include(expected_url)
      end

      it "includes occurred_at timestamp" do
        described_class.new.perform(error_log.id)

        email = ActionMailer::Base.deliveries.last
        expect(email.html_part.body.to_s).to include("Occurred At")
      end

      context "with IP address" do
        let(:error_log) { create(:error_log, ip_address: "192.168.1.1") }

        it "includes IP address in HTML body" do
          described_class.new.perform(error_log.id)

          email = ActionMailer::Base.deliveries.last
          expect(email.html_part.body.to_s).to include("192.168.1.1")
        end
      end

      context "with request URL" do
        let(:error_log) { create(:error_log, request_url: "https://example.com/api/users") }

        it "includes request URL in HTML body" do
          described_class.new.perform(error_log.id)

          email = ActionMailer::Base.deliveries.last
          expect(email.html_part.body.to_s).to include(error_log.request_url)
        end
      end

      context "with backtrace" do
        let(:backtrace) do
          (1..20).map { |i| "app/controllers/users_controller.rb:#{i}:in `show`" }.join("\n")
        end
        let(:error_log) { create(:error_log, backtrace: backtrace) }

        it "includes backtrace in HTML body" do
          described_class.new.perform(error_log.id)

          email = ActionMailer::Base.deliveries.last
          expect(email.html_part.body.to_s).to include("Stack Trace")
        end

        it "truncates backtrace to first 10 lines" do
          described_class.new.perform(error_log.id)

          email = ActionMailer::Base.deliveries.last
          html_body = email.html_part.body.to_s
          expect(html_body).to include("users_controller.rb:1")
          expect(html_body).to include("users_controller.rb:10")
          expect(html_body).not_to include("users_controller.rb:11")
        end
      end

      it "includes error ID in footer" do
        described_class.new.perform(error_log.id)

        email = ActionMailer::Base.deliveries.last
        expect(email.html_part.body.to_s).to include("Error ID: #{error_log.id}")
      end

      it "has both HTML and text parts" do
        described_class.new.perform(error_log.id)

        email = ActionMailer::Base.deliveries.last
        expect(email.html_part).to be_present
        expect(email.text_part).to be_present
      end

      it "includes error type in text body" do
        described_class.new.perform(error_log.id)

        email = ActionMailer::Base.deliveries.last
        expect(email.text_part.body.to_s).to include(error_log.error_type)
      end

      it "includes dashboard URL in text body" do
        described_class.new.perform(error_log.id)

        email = ActionMailer::Base.deliveries.last
        expected_url = "https://example.com/error_dashboard/errors/#{error_log.id}"
        expect(email.text_part.body.to_s).to include(expected_url)
      end
    end

    context "when error log does not exist" do
      it "does not send email" do
        expect {
          described_class.new.perform(999999)
        }.not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context "when recipients are not configured" do
      before do
        RailsErrorDashboard.configuration.notification_email_recipients = nil
      end

      it "does not send email" do
        expect {
          described_class.new.perform(error_log.id)
        }.not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context "when recipients array is empty" do
      before do
        RailsErrorDashboard.configuration.notification_email_recipients = []
      end

      it "does not send email" do
        expect {
          described_class.new.perform(error_log.id)
        }.not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context "when email delivery fails" do
      before do
        mail_message = instance_double(ActionMailer::MessageDelivery)
        allow(RailsErrorDashboard::ErrorNotificationMailer).to receive(:error_alert).and_return(mail_message)
        allow(mail_message).to receive(:deliver_now).and_raise(StandardError.new("SMTP error"))
      end

      it "logs the error" do
        allow(Rails.logger).to receive(:error)

        described_class.new.perform(error_log.id)

        expect(Rails.logger).to have_received(:error).with(/Failed to send email notification/)
      end

      it "does not raise an error" do
        expect {
          described_class.new.perform(error_log.id)
        }.not_to raise_error
      end
    end
  end

  describe "job queue" do
    it "is enqueued to error_notifications queue" do
      expect(described_class.new.queue_name).to eq("error_notifications")
    end
  end
end
