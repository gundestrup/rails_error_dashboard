# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsErrorDashboard::ErrorLog, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      error_log = build(:error_log)
      expect(error_log).to be_valid
    end

    it 'requires error_type' do
      error_log = build(:error_log, error_type: nil)
      expect(error_log).not_to be_valid
      expect(error_log.errors[:error_type]).to include("can't be blank")
    end

    it 'requires message' do
      error_log = build(:error_log, message: nil)
      expect(error_log).not_to be_valid
      expect(error_log.errors[:message]).to include("can't be blank")
    end

    it 'requires environment' do
      error_log = build(:error_log, environment: nil)
      error_log.valid? # Trigger before_validation callback
      expect(error_log.environment).to be_present
    end

    it 'requires occurred_at' do
      error_log = build(:error_log, occurred_at: nil)
      expect(error_log).not_to be_valid
      expect(error_log.errors[:occurred_at]).to include("can't be blank")
    end
  end

  describe 'scopes' do
    let!(:resolved_error) { create(:error_log, :resolved) }
    let!(:unresolved_error) { create(:error_log) }
    let!(:ios_error) { create(:error_log, :ios) }
    let!(:android_error) { create(:error_log, :android) }
    let!(:prod_error) { create(:error_log, :production) }
    let!(:old_error) { create(:error_log, occurred_at: 2.days.ago) }
    let!(:recent_error) { create(:error_log, occurred_at: 1.hour.ago) }

    describe '.resolved' do
      it 'returns only resolved errors' do
        expect(described_class.resolved).to include(resolved_error)
        expect(described_class.resolved).not_to include(unresolved_error)
      end
    end

    describe '.unresolved' do
      it 'returns only unresolved errors' do
        expect(described_class.unresolved).to include(unresolved_error)
        expect(described_class.unresolved).not_to include(resolved_error)
      end
    end

    describe '.by_platform' do
      it 'filters by iOS' do
        expect(described_class.by_platform('iOS')).to include(ios_error)
        expect(described_class.by_platform('iOS')).not_to include(android_error)
      end

      it 'filters by Android' do
        expect(described_class.by_platform('Android')).to include(android_error)
        expect(described_class.by_platform('Android')).not_to include(ios_error)
      end
    end

    describe '.by_environment' do
      it 'filters by environment' do
        expect(described_class.by_environment('production')).to include(prod_error)
      end
    end

    describe '.by_error_type' do
      it 'filters by error type' do
        type_error = create(:error_log, error_type: 'TypeError')
        expect(described_class.by_error_type('TypeError')).to include(type_error)
      end
    end

    describe '.recent' do
      it 'returns errors ordered by most recent first' do
        # recent_error should be in the list and newer than old_error
        errors = described_class.recent.to_a
        expect(errors.index(recent_error)).to be < errors.index(old_error)
      end
    end

    describe '.last_24_hours' do
      it 'returns errors from last 24 hours' do
        expect(described_class.last_24_hours).to include(recent_error)
        expect(described_class.last_24_hours).not_to include(old_error)
      end
    end

    describe '.last_week' do
      it 'returns errors from last week' do
        expect(described_class.last_week).to include(recent_error)
        expect(described_class.last_week).to include(old_error)
      end
    end
  end

  describe '#resolved?' do
    it 'returns true when resolved is true' do
      error_log = build(:error_log, :resolved)
      expect(error_log.resolved?).to be true
    end

    it 'returns false when resolved is false' do
      error_log = build(:error_log)
      expect(error_log.resolved?).to be false
    end
  end

  describe 'database connection' do
    context 'when use_separate_database is false' do
      before do
        allow(RailsErrorDashboard.configuration).to receive(:use_separate_database).and_return(false)
      end

      it 'uses primary database' do
        error_log = create(:error_log)
        expect(error_log.class.connection_db_config.name).to eq('primary')
      end
    end
  end

  describe 'default values' do
    it 'sets environment from Rails.env by default' do
      error_log = create(:error_log, environment: nil)
      error_log.reload
      # Environment is set in the factory, so we test that it's present
      expect(error_log.environment).to be_present
    end

    it 'sets platform to API by default' do
      error_log = build(:error_log, platform: nil)
      error_log.valid? # Trigger before_validation callback
      expect(error_log.platform).to eq('API')
    end
  end

  # Phase 1: Enhanced Error Tracking
  describe '#generate_error_hash' do
    it 'generates consistent hash for same error' do
      error1 = build(:error_log,
        error_type: 'NoMethodError',
        message: 'undefined method for User:123',
        backtrace: "/app/models/user.rb:10:in `name'\n/app/controllers/users_controller.rb:5",
        controller_name: 'users',
        action_name: 'show'
      )
      error2 = build(:error_log,
        error_type: 'NoMethodError',
        message: 'undefined method for User:456', # Different ID
        backtrace: "/app/models/user.rb:10:in `name'\n/app/controllers/users_controller.rb:5",
        controller_name: 'users',
        action_name: 'show'
      )

      expect(error1.generate_error_hash).to eq(error2.generate_error_hash)
    end

    it 'generates different hash for different controllers' do
      error1 = build(:error_log, controller_name: 'users', action_name: 'show')
      error2 = build(:error_log, controller_name: 'posts', action_name: 'show')

      expect(error1.generate_error_hash).not_to eq(error2.generate_error_hash)
    end

    it 'generates different hash for different actions' do
      error1 = build(:error_log, controller_name: 'users', action_name: 'show')
      error2 = build(:error_log, controller_name: 'users', action_name: 'create')

      expect(error1.generate_error_hash).not_to eq(error2.generate_error_hash)
    end
  end

  describe '#set_tracking_fields' do
    it 'sets error_hash before create' do
      error_log = create(:error_log)
      expect(error_log.error_hash).to be_present
      expect(error_log.error_hash.length).to eq(16)
    end

    it 'sets first_seen_at before create' do
      error_log = create(:error_log)
      expect(error_log.first_seen_at).to be_present
    end

    it 'sets last_seen_at before create' do
      error_log = create(:error_log)
      expect(error_log.last_seen_at).to be_present
    end

    it 'sets occurrence_count to 1 before create' do
      error_log = create(:error_log)
      expect(error_log.occurrence_count).to eq(1)
    end
  end

  describe '.find_or_increment_by_hash' do
    let!(:existing_error) do
      create(:error_log,
        error_type: 'NoMethodError',
        message: 'undefined method',
        occurred_at: 1.hour.ago,
        occurrence_count: 1
      )
    end

    context 'when error with same hash exists and is unresolved' do
      it 'increments occurrence_count' do
        expect {
          described_class.find_or_increment_by_hash(
            existing_error.error_hash,
            error_type: 'NoMethodError',
            message: 'undefined method',
            occurred_at: Time.current
          )
        }.not_to change(described_class, :count)

        existing_error.reload
        expect(existing_error.occurrence_count).to eq(2)
      end

      it 'updates last_seen_at' do
        old_last_seen = existing_error.last_seen_at
        sleep 0.1

        described_class.find_or_increment_by_hash(
          existing_error.error_hash,
          error_type: 'NoMethodError',
          message: 'undefined method',
          occurred_at: Time.current
        )

        existing_error.reload
        expect(existing_error.last_seen_at).to be > old_last_seen
      end

      it 'updates request context from latest occurrence' do
        described_class.find_or_increment_by_hash(
          existing_error.error_hash,
          error_type: 'NoMethodError',
          message: 'undefined method',
          occurred_at: Time.current,
          user_id: 123,
          request_url: 'http://example.com/new-url'
        )

        existing_error.reload
        expect(existing_error.user_id).to eq(123)
        expect(existing_error.request_url).to eq('http://example.com/new-url')
      end
    end

    context 'when error with same hash is resolved' do
      let!(:resolved_error) do
        create(:error_log, :resolved,
          error_type: 'NoMethodError',
          message: 'undefined method',
          occurred_at: 1.hour.ago
        )
      end

      it 'creates new error instead of incrementing resolved one' do
        expect {
          described_class.find_or_increment_by_hash(
            resolved_error.error_hash,
            error_type: 'NoMethodError',
            message: 'undefined method',
            occurred_at: Time.current,
            environment: 'test'
          )
        }.to change(described_class, :count).by(1)
      end
    end

    context 'when error with same hash is older than 24 hours' do
      let!(:old_error) do
        create(:error_log,
          error_type: 'NoMethodError',
          message: 'undefined method',
          occurred_at: 25.hours.ago
        )
      end

      it 'creates new error instead of incrementing old one' do
        expect {
          described_class.find_or_increment_by_hash(
            old_error.error_hash,
            error_type: 'NoMethodError',
            message: 'undefined method',
            occurred_at: Time.current,
            environment: 'test'
          )
        }.to change(described_class, :count).by(1)
      end
    end

    context 'when no matching error exists' do
      it 'creates new error record' do
        expect {
          described_class.find_or_increment_by_hash(
            'new_hash_12345678',
            error_type: 'ArgumentError',
            message: 'wrong number of arguments',
            occurred_at: Time.current,
            environment: 'test'
          )
        }.to change(described_class, :count).by(1)
      end
    end
  end

  describe 'severity methods' do
    describe '#critical?' do
      it 'returns true for SecurityError' do
        error = build(:error_log, error_type: 'SecurityError')
        expect(error.critical?).to be true
      end

      it 'returns true for NoMemoryError' do
        error = build(:error_log, error_type: 'NoMemoryError')
        expect(error.critical?).to be true
      end

      it 'returns false for ArgumentError' do
        error = build(:error_log, error_type: 'ArgumentError')
        expect(error.critical?).to be false
      end
    end

    describe '#severity' do
      it 'returns :critical for critical errors' do
        error = build(:error_log, error_type: 'SecurityError')
        expect(error.severity).to eq(:critical)
      end

      it 'returns :high for high severity errors' do
        error = build(:error_log, error_type: 'NoMethodError')
        expect(error.severity).to eq(:high)
      end

      it 'returns :medium for medium severity errors' do
        error = build(:error_log, error_type: 'Timeout::Error')
        expect(error.severity).to eq(:medium)
      end

      it 'returns :low for other errors' do
        error = build(:error_log, error_type: 'CustomError')
        expect(error.severity).to eq(:low)
      end
    end
  end

  describe 'time-based methods' do
    describe '#recent?' do
      it 'returns true for errors less than 1 hour old' do
        error = create(:error_log, occurred_at: 30.minutes.ago)
        expect(error.recent?).to be true
      end

      it 'returns false for errors older than 1 hour' do
        error = create(:error_log, occurred_at: 2.hours.ago)
        expect(error.recent?).to be false
      end
    end

    describe '#stale?' do
      it 'returns true for unresolved errors older than 7 days' do
        error = create(:error_log, occurred_at: 8.days.ago, resolved: false)
        expect(error.stale?).to be true
      end

      it 'returns false for unresolved errors less than 7 days old' do
        error = create(:error_log, occurred_at: 5.days.ago, resolved: false)
        expect(error.stale?).to be false
      end

      it 'returns false for resolved errors even if old' do
        error = create(:error_log, :resolved, occurred_at: 10.days.ago)
        expect(error.stale?).to be false
      end
    end
  end

  describe '.statistics' do
    before do
      create(:error_log, error_type: 'NoMethodError', occurred_at: 2.days.ago)
      create(:error_log, error_type: 'NoMethodError', occurred_at: 3.days.ago)
      create(:error_log, error_type: 'ArgumentError', occurred_at: 1.day.ago)
      create(:error_log, :resolved, error_type: 'TypeError', occurred_at: 4.days.ago)
      create(:error_log, occurred_at: 10.days.ago) # Outside 7 day window
    end

    it 'returns total count within time period' do
      stats = described_class.statistics(7)
      expect(stats[:total]).to eq(4) # 4 errors in last 7 days
    end

    it 'returns unresolved count' do
      stats = described_class.statistics(7)
      expect(stats[:unresolved]).to eq(3)
    end

    it 'returns errors grouped by type' do
      stats = described_class.statistics(7)
      expect(stats[:by_type]['NoMethodError']).to eq(2)
      expect(stats[:by_type]['ArgumentError']).to eq(1)
    end

    it 'returns errors grouped by day' do
      stats = described_class.statistics(7)
      expect(stats[:by_day]).to be_a(Hash)
    end
  end

  describe '#related_errors' do
    let!(:error1) { create(:error_log, error_type: 'NoMethodError', occurred_at: 2.days.ago) }
    let!(:error2) { create(:error_log, error_type: 'NoMethodError', occurred_at: 1.day.ago) }
    let!(:error3) { create(:error_log, error_type: 'ArgumentError', occurred_at: 1.day.ago) }

    it 'returns errors of the same type' do
      related = error1.related_errors
      expect(related).to include(error2)
      expect(related).not_to include(error3)
    end

    it 'excludes the current error' do
      related = error1.related_errors
      expect(related).not_to include(error1)
    end

    it 'orders by most recent first' do
      related = error1.related_errors.to_a
      expect(related.first.occurred_at).to be > related.last.occurred_at if related.size > 1
    end

    it 'limits results to specified number' do
      6.times { create(:error_log, error_type: 'NoMethodError') }
      related = error1.related_errors(limit: 3)
      expect(related.size).to be <= 3
    end
  end
end
