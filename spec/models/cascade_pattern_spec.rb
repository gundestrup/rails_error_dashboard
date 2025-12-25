# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsErrorDashboard::CascadePattern, type: :model do
  describe "associations" do
    it "belongs to parent_error" do
      pattern = build(:cascade_pattern)
      expect(pattern).to respond_to(:parent_error)
      expect(pattern.parent_error).to be_a(RailsErrorDashboard::ErrorLog)
    end

    it "belongs to child_error" do
      pattern = build(:cascade_pattern)
      expect(pattern).to respond_to(:child_error)
      expect(pattern.child_error).to be_a(RailsErrorDashboard::ErrorLog)
    end
  end

  describe "validations" do
    it "validates presence of parent_error_id" do
      pattern = build(:cascade_pattern)
      pattern.parent_error_id = nil
      expect(pattern).not_to be_valid
      expect(pattern.errors[:parent_error_id]).to include("can't be blank")
    end

    it "validates presence of child_error_id" do
      pattern = build(:cascade_pattern)
      pattern.child_error_id = nil
      expect(pattern).not_to be_valid
      expect(pattern.errors[:child_error_id]).to include("can't be blank")
    end

    it "validates presence of frequency" do
      pattern = build(:cascade_pattern)
      pattern.frequency = nil
      expect(pattern).not_to be_valid
      expect(pattern.errors[:frequency]).to include("can't be blank")
    end

    it "validates frequency is greater than 0" do
      pattern = build(:cascade_pattern)
      pattern.frequency = 0
      expect(pattern).not_to be_valid
      expect(pattern.errors[:frequency]).to include("must be greater than 0")
    end

    it "validates parent and child must be different" do
      parent = create(:error_log)
      pattern = build(:cascade_pattern, parent_error: parent, child_error: parent)
      expect(pattern).not_to be_valid
      expect(pattern.errors[:child_error_id]).to include("cannot be the same as parent error")
    end
  end

  describe "scopes" do
    let!(:high_confidence_pattern) { create(:cascade_pattern, cascade_probability: 0.8, frequency: 5, last_detected_at: 1.day.ago) }
    let!(:low_confidence_pattern) { create(:cascade_pattern, cascade_probability: 0.5, frequency: 2, last_detected_at: 2.days.ago) }
    let!(:recent_pattern) { create(:cascade_pattern, last_detected_at: 1.hour.ago) }
    let!(:old_pattern) { create(:cascade_pattern, last_detected_at: 1.week.ago) }

    describe ".high_confidence" do
      it "returns patterns with cascade_probability >= 0.7" do
        results = described_class.high_confidence
        expect(results).to include(high_confidence_pattern)
        expect(results).not_to include(low_confidence_pattern)
      end
    end

    describe ".frequent" do
      it "returns patterns with frequency >= min_frequency" do
        results = described_class.frequent(3)
        expect(results).to include(high_confidence_pattern)
        expect(results).not_to include(low_confidence_pattern)
      end

      it "defaults to frequency >= 3" do
        results = described_class.frequent
        expect(results).to include(high_confidence_pattern)
        expect(results).not_to include(low_confidence_pattern)
      end
    end

    describe ".recent" do
      it "orders by last_detected_at desc" do
        results = described_class.recent
        expect(results.first).to eq(recent_pattern)
      end
    end

    describe ".by_parent" do
      it "returns patterns for a specific parent error" do
        results = described_class.by_parent(high_confidence_pattern.parent_error_id)
        expect(results).to include(high_confidence_pattern)
        expect(results).not_to include(low_confidence_pattern)
      end
    end

    describe ".by_child" do
      it "returns patterns for a specific child error" do
        results = described_class.by_child(high_confidence_pattern.child_error_id)
        expect(results).to include(high_confidence_pattern)
        expect(results).not_to include(low_confidence_pattern)
      end
    end
  end

  describe "#increment_detection!" do
    it "increments frequency" do
      pattern = create(:cascade_pattern, frequency: 3)
      expect { pattern.increment_detection!(20.0) }.to change { pattern.frequency }.from(3).to(4)
    end

    it "updates average delay using incremental formula" do
      pattern = create(:cascade_pattern, frequency: 3, avg_delay_seconds: 15.0)
      pattern.increment_detection!(27.0)
      # New avg = ((15.0 * 3) + 27.0) / 4 = (45 + 27) / 4 = 72 / 4 = 18.0
      expect(pattern.avg_delay_seconds).to eq(18.0)
    end

    it "sets avg_delay_seconds if not present" do
      pattern = create(:cascade_pattern, avg_delay_seconds: nil)
      pattern.increment_detection!(25.0)
      expect(pattern.avg_delay_seconds).to eq(25.0)
    end

    it "updates last_detected_at" do
      pattern = create(:cascade_pattern, last_detected_at: 1.day.ago)
      expect { pattern.increment_detection!(20.0) }.to change { pattern.last_detected_at }
    end

    it "persists changes" do
      pattern = create(:cascade_pattern, frequency: 3)
      pattern.increment_detection!(20.0)
      pattern.reload
      expect(pattern.frequency).to eq(4)
    end
  end

  describe "#calculate_probability!" do
    it "calculates cascade probability based on parent occurrences" do
      parent = create(:error_log)
      child = create(:error_log)
      pattern = create(:cascade_pattern, parent_error: parent, child_error: child, frequency: 7)

      # Create 10 occurrences for parent
      10.times { create(:error_occurrence, error_log: parent, occurred_at: 1.hour.ago) }

      pattern.calculate_probability!
      # Probability = 7 / 10 = 0.7
      expect(pattern.cascade_probability).to eq(0.7)
    end

    it "does not calculate if parent has no occurrences" do
      pattern = create(:cascade_pattern, frequency: 5, cascade_probability: nil)
      pattern.calculate_probability!
      expect(pattern.cascade_probability).to be_nil
    end

    it "rounds to 3 decimal places" do
      parent = create(:error_log)
      child = create(:error_log)
      pattern = create(:cascade_pattern, parent_error: parent, child_error: child, frequency: 2)

      # Create 3 occurrences for parent
      3.times { create(:error_occurrence, error_log: parent, occurred_at: 1.hour.ago) }

      pattern.calculate_probability!
      # Probability = 2 / 3 = 0.667
      expect(pattern.cascade_probability).to eq(0.667)
    end

    it "persists the probability" do
      parent = create(:error_log)
      child = create(:error_log)
      pattern = create(:cascade_pattern, parent_error: parent, child_error: child, frequency: 5)

      5.times { create(:error_occurrence, error_log: parent, occurred_at: 1.hour.ago) }

      pattern.calculate_probability!
      pattern.reload
      expect(pattern.cascade_probability).to eq(1.0)
    end
  end

  describe "#strong_cascade?" do
    it "returns true for high probability and high frequency" do
      pattern = build(:cascade_pattern, cascade_probability: 0.8, frequency: 5)
      expect(pattern.strong_cascade?).to be true
    end

    it "returns false if probability is below 0.7" do
      pattern = build(:cascade_pattern, cascade_probability: 0.6, frequency: 5)
      expect(pattern.strong_cascade?).to be false
    end

    it "returns false if frequency is below 3" do
      pattern = build(:cascade_pattern, cascade_probability: 0.8, frequency: 2)
      expect(pattern.strong_cascade?).to be false
    end

    it "returns false if probability is nil" do
      pattern = build(:cascade_pattern, cascade_probability: nil, frequency: 5)
      expect(pattern.strong_cascade?).to be false
    end

    it "returns true at exactly 0.7 probability and 3 frequency" do
      pattern = build(:cascade_pattern, cascade_probability: 0.7, frequency: 3)
      expect(pattern.strong_cascade?).to be true
    end
  end
end
