# frozen_string_literal: true

require "rails_helper"

RSpec.describe RailsErrorDashboard::ErrorOccurrence, type: :model do
  describe "associations" do
    it "belongs to error_log" do
      occurrence = build(:error_occurrence)
      expect(occurrence).to respond_to(:error_log)
    end

    if defined?(::User)
      it "belongs to user" do
        occurrence = build(:error_occurrence)
        expect(occurrence).to respond_to(:user)
      end
    end
  end

  describe "validations" do
    it "validates presence of occurred_at" do
      occurrence = build(:error_occurrence)
      occurrence.occurred_at = nil
      expect(occurrence).not_to be_valid
      expect(occurrence.errors[:occurred_at]).to include("can't be blank")
    end

    it "validates presence of error_log_id" do
      occurrence = build(:error_occurrence)
      occurrence.error_log_id = nil
      expect(occurrence).not_to be_valid
      expect(occurrence.errors[:error_log_id]).to include("can't be blank")
    end
  end

  describe "scopes" do
    let!(:error_log) { create(:error_log) }
    let!(:occurrence1) { create(:error_occurrence, error_log: error_log, occurred_at: 1.hour.ago) }
    let!(:occurrence2) { create(:error_occurrence, error_log: error_log, occurred_at: 2.hours.ago) }
    let!(:occurrence3) { create(:error_occurrence, error_log: error_log, occurred_at: 3.hours.ago) }

    describe ".recent" do
      it "orders by occurred_at descending" do
        results = described_class.recent
        expect(results.first).to eq(occurrence1)
        expect(results.last).to eq(occurrence3)
      end
    end

    describe ".in_time_window" do
      it "finds occurrences within time window" do
        start_time = 2.5.hours.ago
        end_time = 30.minutes.ago

        results = described_class.in_time_window(start_time, end_time)
        expect(results).to include(occurrence1, occurrence2)
        expect(results).not_to include(occurrence3)
      end
    end

    describe ".for_user" do
      let!(:user_occurrence) { create(:error_occurrence, error_log: error_log, user_id: 123) }

      it "filters by user_id" do
        results = described_class.for_user(123)
        expect(results).to include(user_occurrence)
        expect(results).not_to include(occurrence1)
      end
    end

    describe ".for_request" do
      let!(:request_occurrence) { create(:error_occurrence, error_log: error_log, request_id: "req-123") }

      it "filters by request_id" do
        results = described_class.for_request("req-123")
        expect(results).to include(request_occurrence)
        expect(results).not_to include(occurrence1)
      end
    end

    describe ".for_session" do
      let!(:session_occurrence) { create(:error_occurrence, error_log: error_log, session_id: "sess-456") }

      it "filters by session_id" do
        results = described_class.for_session("sess-456")
        expect(results).to include(session_occurrence)
        expect(results).not_to include(occurrence1)
      end
    end
  end

  describe "#nearby_occurrences" do
    let(:error_log) { create(:error_log) }
    let(:center_time) { Time.current }
    let!(:target_occurrence) { create(:error_occurrence, error_log: error_log, occurred_at: center_time) }

    it "finds occurrences within default 5-minute window" do
      nearby = create(:error_occurrence, error_log: error_log, occurred_at: center_time + 3.minutes)
      far = create(:error_occurrence, error_log: error_log, occurred_at: center_time + 10.minutes)

      results = target_occurrence.nearby_occurrences
      expect(results).to include(nearby)
      expect(results).not_to include(far)
    end

    it "excludes the target occurrence itself" do
      results = target_occurrence.nearby_occurrences
      expect(results).not_to include(target_occurrence)
    end

    it "respects custom window_minutes parameter" do
      nearby = create(:error_occurrence, error_log: error_log, occurred_at: center_time + 8.minutes)
      far = create(:error_occurrence, error_log: error_log, occurred_at: center_time + 15.minutes)

      results = target_occurrence.nearby_occurrences(window_minutes: 10)
      expect(results).to include(nearby)
      expect(results).not_to include(far)
    end

    it "finds occurrences both before and after" do
      before_occ = create(:error_occurrence, error_log: error_log, occurred_at: center_time - 2.minutes)
      after_occ = create(:error_occurrence, error_log: error_log, occurred_at: center_time + 2.minutes)

      results = target_occurrence.nearby_occurrences
      expect(results).to include(before_occ, after_occ)
    end
  end

  describe "#co_occurring_error_types" do
    let(:error_log_a) { create(:error_log, error_type: "NoMethodError") }
    let(:error_log_b) { create(:error_log, error_type: "ArgumentError") }
    let(:error_log_c) { create(:error_log, error_type: "RuntimeError") }
    let(:center_time) { Time.current }

    let!(:target_occurrence) { create(:error_occurrence, error_log: error_log_a, occurred_at: center_time) }

    it "finds different error types that occurred nearby" do
      create(:error_occurrence, error_log: error_log_b, occurred_at: center_time + 2.minutes)
      create(:error_occurrence, error_log: error_log_c, occurred_at: center_time - 3.minutes)

      results = target_occurrence.co_occurring_error_types
      expect(results).to include(error_log_b, error_log_c)
    end

    it "excludes same error type" do
      create(:error_occurrence, error_log: error_log_a, occurred_at: center_time + 1.minute)

      results = target_occurrence.co_occurring_error_types
      expect(results).not_to include(error_log_a)
    end

    it "respects window_minutes parameter" do
      create(:error_occurrence, error_log: error_log_b, occurred_at: center_time + 3.minutes)
      create(:error_occurrence, error_log: error_log_c, occurred_at: center_time + 8.minutes)

      results = target_occurrence.co_occurring_error_types(window_minutes: 5)
      expect(results).to include(error_log_b)
      expect(results).not_to include(error_log_c)
    end

    it "returns distinct error logs" do
      # Multiple occurrences of same error type
      create(:error_occurrence, error_log: error_log_b, occurred_at: center_time + 1.minute)
      create(:error_occurrence, error_log: error_log_b, occurred_at: center_time + 2.minutes)

      results = target_occurrence.co_occurring_error_types
      expect(results.count).to eq(1)
      expect(results.first).to eq(error_log_b)
    end
  end
end
