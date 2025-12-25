# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsErrorDashboard::Services::BaselineCalculator do
  describe "#calculate_for_error_type" do
    let(:error_type) { "NoMethodError" }
    let(:platform) { "iOS" }

    before do
      # Create errors over the past weeks
      30.times do |i|
        create(:error_log, error_type: error_type, platform: platform, occurred_at: i.days.ago)
      end
    end

    it "calculates hourly, daily, and weekly baselines" do
      result = described_class.calculate_for_error_type(error_type, platform)

      expect(result[:hourly]).to be_a(RailsErrorDashboard::ErrorBaseline)
      expect(result[:daily]).to be_a(RailsErrorDashboard::ErrorBaseline)
      expect(result[:weekly]).to be_a(RailsErrorDashboard::ErrorBaseline)
    end

    it "sets correct baseline_type for each" do
      result = described_class.calculate_for_error_type(error_type, platform)

      expect(result[:hourly].baseline_type).to eq("hourly")
      expect(result[:daily].baseline_type).to eq("daily")
      expect(result[:weekly].baseline_type).to eq("weekly")
    end

    it "calculates statistical metrics" do
      result = described_class.calculate_for_error_type(error_type, platform)
      baseline = result[:daily]

      expect(baseline.mean).to be_present
      expect(baseline.std_dev).to be_present
      expect(baseline.percentile_95).to be_present
      expect(baseline.percentile_99).to be_present
      expect(baseline.sample_size).to be > 0
    end
  end

  describe "#calculate_all_baselines" do
    it "calculates baselines for all error type/platform combinations" do
      create(:error_log, error_type: "NoMethodError", platform: "iOS", occurred_at: 1.day.ago)
      create(:error_log, error_type: "ArgumentError", platform: "Android", occurred_at: 1.day.ago)

      result = described_class.calculate_all_baselines

      expect(result[:calculated]).to be > 0
    end
  end
end
