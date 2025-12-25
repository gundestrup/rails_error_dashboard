# frozen_string_literal: true

FactoryBot.define do
  factory :cascade_pattern, class: 'RailsErrorDashboard::CascadePattern' do
    association :parent_error, factory: :error_log
    association :child_error, factory: :error_log
    frequency { 3 }
    avg_delay_seconds { 15.5 }
    cascade_probability { 0.75 }
    last_detected_at { Time.current }
  end
end
