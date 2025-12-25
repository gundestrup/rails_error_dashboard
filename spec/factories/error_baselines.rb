# frozen_string_literal: true

FactoryBot.define do
  factory :error_baseline, class: 'RailsErrorDashboard::ErrorBaseline' do
    error_type { "NoMethodError" }
    platform { "iOS" }
    baseline_type { "daily" }
    period_start { 1.week.ago }
    period_end { Time.current }
    count { 50 }
    mean { 7.2 }
    std_dev { 2.1 }
    percentile_95 { 11.0 }
    percentile_99 { 13.5 }
    sample_size { 7 }

    trait :hourly do
      baseline_type { "hourly" }
      period_start { 4.weeks.ago }
      mean { 5.5 }
      std_dev { 1.8 }
    end

    trait :weekly do
      baseline_type { "weekly" }
      period_start { 1.year.ago }
      mean { 45.0 }
      std_dev { 12.3 }
    end
  end
end
