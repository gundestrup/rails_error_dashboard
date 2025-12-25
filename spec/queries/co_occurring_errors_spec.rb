# frozen_string_literal: true

require "rails_helper"

RSpec.describe RailsErrorDashboard::Queries::CoOccurringErrors do
  describe ".call" do
    let(:error_a) { create(:error_log, error_type: "NoMethodError") }
    let(:error_b) { create(:error_log, error_type: "ArgumentError") }
    let(:error_c) { create(:error_log, error_type: "RuntimeError") }
    let(:center_time) { Time.current }

    it "returns empty array if error not found" do
      result = described_class.call(error_log_id: 99999)
      expect(result).to eq([])
    end

    it "returns empty array if no occurrences exist" do
      result = described_class.call(error_log_id: error_a.id)
      expect(result).to eq([])
    end

    it "finds errors that occur together" do
      # Create 3 occurrences of error_a
      create(:error_occurrence, error_log: error_a, occurred_at: center_time)
      create(:error_occurrence, error_log: error_a, occurred_at: center_time + 1.hour)
      create(:error_occurrence, error_log: error_a, occurred_at: center_time + 2.hours)

      # Create error_b occurrences near error_a
      create(:error_occurrence, error_log: error_b, occurred_at: center_time + 2.minutes)
      create(:error_occurrence, error_log: error_b, occurred_at: center_time + 1.hour + 3.minutes)

      result = described_class.call(error_log_id: error_a.id, min_frequency: 2)

      expect(result.size).to eq(1)
      expect(result.first[:error]).to eq(error_b)
      expect(result.first[:frequency]).to eq(2)
    end

    it "respects window_minutes parameter" do
      create(:error_occurrence, error_log: error_a, occurred_at: center_time)

      # Within 5 minutes
      create(:error_occurrence, error_log: error_b, occurred_at: center_time + 3.minutes)

      # Beyond 5 minutes
      create(:error_occurrence, error_log: error_c, occurred_at: center_time + 8.minutes)

      result = described_class.call(error_log_id: error_a.id, window_minutes: 5, min_frequency: 1)

      error_ids = result.map { |r| r[:error].id }
      expect(error_ids).to include(error_b.id)
      expect(error_ids).not_to include(error_c.id)
    end

    it "respects min_frequency parameter" do
      # Create 2 occurrences of error_a
      create(:error_occurrence, error_log: error_a, occurred_at: center_time)
      create(:error_occurrence, error_log: error_a, occurred_at: center_time + 1.hour)

      # error_b occurs twice with error_a
      create(:error_occurrence, error_log: error_b, occurred_at: center_time + 1.minute)
      create(:error_occurrence, error_log: error_b, occurred_at: center_time + 1.hour + 1.minute)

      # error_c occurs only once
      create(:error_occurrence, error_log: error_c, occurred_at: center_time + 2.minutes)

      result = described_class.call(error_log_id: error_a.id, min_frequency: 2)

      error_ids = result.map { |r| r[:error].id }
      expect(error_ids).to include(error_b.id)
      expect(error_ids).not_to include(error_c.id)
    end

    it "sorts results by frequency descending" do
      create(:error_occurrence, error_log: error_a, occurred_at: center_time)
      create(:error_occurrence, error_log: error_a, occurred_at: center_time + 1.hour)
      create(:error_occurrence, error_log: error_a, occurred_at: center_time + 2.hours)

      # error_b occurs 3 times
      create(:error_occurrence, error_log: error_b, occurred_at: center_time + 1.minute)
      create(:error_occurrence, error_log: error_b, occurred_at: center_time + 1.hour + 1.minute)
      create(:error_occurrence, error_log: error_b, occurred_at: center_time + 2.hours + 1.minute)

      # error_c occurs 2 times
      create(:error_occurrence, error_log: error_c, occurred_at: center_time + 2.minutes)
      create(:error_occurrence, error_log: error_c, occurred_at: center_time + 1.hour + 2.minutes)

      result = described_class.call(error_log_id: error_a.id, min_frequency: 1)

      expect(result.first[:error]).to eq(error_b)
      expect(result.first[:frequency]).to eq(3)
      expect(result.second[:error]).to eq(error_c)
      expect(result.second[:frequency]).to eq(2)
    end

    it "calculates average delay correctly" do
      create(:error_occurrence, error_log: error_a, occurred_at: center_time)
      create(:error_occurrence, error_log: error_a, occurred_at: center_time + 1.hour)

      # error_b occurs 2 minutes after first, 3 minutes after second
      create(:error_occurrence, error_log: error_b, occurred_at: center_time + 2.minutes)
      create(:error_occurrence, error_log: error_b, occurred_at: center_time + 1.hour + 3.minutes)

      result = described_class.call(error_log_id: error_a.id, min_frequency: 2)

      # Average delay should be (120 + 180) / 2 = 150 seconds
      expect(result.first[:avg_delay_seconds]).to be_within(1).of(150)
    end

    it "respects limit parameter" do
      create(:error_occurrence, error_log: error_a, occurred_at: center_time)

      # Create 5 different co-occurring errors
      errors = 5.times.map { create(:error_log) }
      errors.each do |error|
        create(:error_occurrence, error_log: error, occurred_at: center_time + 1.minute)
      end

      result = described_class.call(error_log_id: error_a.id, limit: 3, min_frequency: 1)

      expect(result.size).to eq(3)
    end
  end
end
