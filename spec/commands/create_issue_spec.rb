# frozen_string_literal: true

require "rails_helper"

RSpec.describe RailsErrorDashboard::Commands::CreateIssue do
  let(:error_log) { create(:error_log, occurred_at: 1.day.ago) }

  before do
    RailsErrorDashboard.configuration.enable_issue_tracking = true
    RailsErrorDashboard.configuration.issue_tracker_provider = :github
    RailsErrorDashboard.configuration.issue_tracker_token = "ghp_test123"
    RailsErrorDashboard.configuration.issue_tracker_repo = "user/repo"
  end

  after { RailsErrorDashboard.reset_configuration! }

  describe ".call" do
    it "creates an issue and stores the URL on the error" do
      stub_request(:post, "https://api.github.com/repos/user/repo/issues")
        .to_return(status: 201, body: {
          html_url: "https://github.com/user/repo/issues/42",
          number: 42
        }.to_json)

      result = described_class.call(error_log.id, dashboard_url: "https://app.com/errors/#{error_log.id}")

      expect(result[:success]).to be true
      expect(result[:issue_url]).to eq("https://github.com/user/repo/issues/42")
      expect(result[:issue_number]).to eq(42)

      error_log.reload
      expect(error_log.external_issue_url).to eq("https://github.com/user/repo/issues/42")
      expect(error_log.external_issue_number).to eq(42)
      expect(error_log.external_issue_provider).to eq("github")
    end

    it "returns error if issue tracking is not configured" do
      RailsErrorDashboard.configuration.enable_issue_tracking = false
      result = described_class.call(error_log.id)
      expect(result[:success]).to be false
      expect(result[:error]).to include("not configured")
    end

    it "returns error if error already has a linked issue" do
      error_log.update!(external_issue_url: "https://github.com/user/repo/issues/99")
      result = described_class.call(error_log.id)
      expect(result[:success]).to be false
      expect(result[:error]).to include("already has a linked issue")
    end

    it "returns error on API failure" do
      stub_request(:post, "https://api.github.com/repos/user/repo/issues")
        .to_return(status: 422, body: { message: "Validation Failed" }.to_json)

      result = described_class.call(error_log.id)
      expect(result[:success]).to be false
      expect(result[:error]).to include("422")
    end

    it "returns error for non-existent error" do
      result = described_class.call(999_999)
      expect(result[:success]).to be false
      expect(result[:error]).to include("not found")
    end

    it "includes error type in issue title" do
      stub_request(:post, "https://api.github.com/repos/user/repo/issues")
        .with(body: hash_including("title" => /#{error_log.error_type}/))
        .to_return(status: 201, body: { html_url: "https://github.com/user/repo/issues/1", number: 1 }.to_json)

      described_class.call(error_log.id)
    end
  end
end
