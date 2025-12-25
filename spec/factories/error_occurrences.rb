# frozen_string_literal: true

FactoryBot.define do
  factory :error_occurrence, class: 'RailsErrorDashboard::ErrorOccurrence' do
    association :error_log, factory: :error_log
    occurred_at { Time.current }
    user_id { nil }
    request_id { nil }
    session_id { nil }
  end
end
