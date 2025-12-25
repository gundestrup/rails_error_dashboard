# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsErrorDashboard::Queries::BaselineStats do
  let(:error_type) { "NoMethodError" }
  let(:platform) { "iOS" }

  describe ".hourly_baseline" do
    it "returns most recent hourly baseline" do
      create(:error_baseline, :hourly, error_type: error_type, platform: platform, period_start: 2.weeks.ago)
      recent = create(:error_baseline, :hourly, error_type: error_type, platform: platform, period_start: 1.week.ago)

      result = described_class.hourly_baseline(error_type, platform)
      expect(result.id).to eq(recent.id)
    end
  end

  describe "#check_anomaly" do
    let!(:baseline) { create(:error_baseline, error_type: error_type, platform: platform, mean: 10.0, std_dev: 2.0) }
    let(:stats) { described_class.new(error_type, platform) }

    it "detects anomaly when count exceeds threshold" do
      result = stats.check_anomaly(15) # 10 + 2.5*2 = 15
      expect(result[:anomaly]).to be true
      expect(result[:level]).to be_in([:elevated, :high, :critical])
    end

    it "returns no anomaly for normal count" do
      result = stats.check_anomaly(10)
      expect(result[:anomaly]).to be false
    end

    it "includes threshold and std_devs_above in result" do
      result = stats.check_anomaly(15)
      expect(result[:threshold]).to be_present
      expect(result[:std_devs_above]).to be_present
    end
  end
end
