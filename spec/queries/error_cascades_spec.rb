# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsErrorDashboard::Queries::ErrorCascades do
  describe ".call" do
    let(:target_error) { create(:error_log, error_type: "TargetError") }
    let(:parent_error1) { create(:error_log, error_type: "ParentError1") }
    let(:parent_error2) { create(:error_log, error_type: "ParentError2") }
    let(:child_error1) { create(:error_log, error_type: "ChildError1") }
    let(:child_error2) { create(:error_log, error_type: "ChildError2") }

    before do
      # Create parent cascade patterns (errors that cause target_error)
      create(:cascade_pattern,
        parent_error: parent_error1,
        child_error: target_error,
        frequency: 10,
        cascade_probability: 0.85,
        avg_delay_seconds: 12.5)

      create(:cascade_pattern,
        parent_error: parent_error2,
        child_error: target_error,
        frequency: 5,
        cascade_probability: 0.6,
        avg_delay_seconds: 8.0)

      # Create child cascade patterns (errors caused by target_error)
      create(:cascade_pattern,
        parent_error: target_error,
        child_error: child_error1,
        frequency: 8,
        cascade_probability: 0.75,
        avg_delay_seconds: 15.0)

      create(:cascade_pattern,
        parent_error: target_error,
        child_error: child_error2,
        frequency: 3,
        cascade_probability: 0.55,
        avg_delay_seconds: 20.0)
    end

    it "returns both parents and children cascades" do
      result = described_class.call(error_id: target_error.id)

      expect(result).to be_a(Hash)
      expect(result).to have_key(:parents)
      expect(result).to have_key(:children)
    end

    it "returns parent cascades with high probability" do
      result = described_class.call(error_id: target_error.id, min_probability: 0.5)

      expect(result[:parents].size).to eq(2)

      parent_errors = result[:parents].map { |p| p[:error] }
      expect(parent_errors).to include(parent_error1, parent_error2)
    end

    it "filters parent cascades by min_probability" do
      result = described_class.call(error_id: target_error.id, min_probability: 0.7)

      expect(result[:parents].size).to eq(1)
      expect(result[:parents].first[:error]).to eq(parent_error1)
    end

    it "returns child cascades with high probability" do
      result = described_class.call(error_id: target_error.id, min_probability: 0.5)

      expect(result[:children].size).to eq(2)

      child_errors = result[:children].map { |c| c[:error] }
      expect(child_errors).to include(child_error1, child_error2)
    end

    it "filters child cascades by min_probability" do
      result = described_class.call(error_id: target_error.id, min_probability: 0.7)

      expect(result[:children].size).to eq(1)
      expect(result[:children].first[:error]).to eq(child_error1)
    end

    it "includes cascade metadata for parents" do
      result = described_class.call(error_id: target_error.id, min_probability: 0.5)

      parent_cascade = result[:parents].find { |p| p[:error] == parent_error1 }
      expect(parent_cascade[:frequency]).to eq(10)
      expect(parent_cascade[:probability]).to eq(0.85)
      expect(parent_cascade[:avg_delay_seconds]).to eq(12.5)
    end

    it "includes cascade metadata for children" do
      result = described_class.call(error_id: target_error.id, min_probability: 0.5)

      child_cascade = result[:children].find { |c| c[:error] == child_error1 }
      expect(child_cascade[:frequency]).to eq(8)
      expect(child_cascade[:probability]).to eq(0.75)
      expect(child_cascade[:avg_delay_seconds]).to eq(15.0)
    end

    it "orders parents by probability descending" do
      result = described_class.call(error_id: target_error.id, min_probability: 0.5)

      probabilities = result[:parents].map { |p| p[:probability] }
      expect(probabilities).to eq(probabilities.sort.reverse)
    end

    it "orders children by probability descending" do
      result = described_class.call(error_id: target_error.id, min_probability: 0.5)

      probabilities = result[:children].map { |c| c[:probability] }
      expect(probabilities).to eq(probabilities.sort.reverse)
    end

    it "returns empty arrays if no cascades exist" do
      other_error = create(:error_log)
      result = described_class.call(error_id: other_error.id)

      expect(result[:parents]).to eq([])
      expect(result[:children]).to eq([])
    end

    it "returns empty arrays if error does not exist" do
      result = described_class.call(error_id: 99999)

      expect(result[:parents]).to eq([])
      expect(result[:children]).to eq([])
    end

    it "uses default min_probability of 0.5" do
      result = described_class.call(error_id: target_error.id)

      # Should include patterns with probability >= 0.5
      expect(result[:parents].size).to eq(2)
      expect(result[:children].size).to eq(2)
    end
  end
end
