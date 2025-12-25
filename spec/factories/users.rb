# frozen_string_literal: true

require 'ostruct'

# Mock User factory for testing
FactoryBot.define do
  factory :user, class: OpenStruct do
    sequence(:id) { |n| n }
    sequence(:email) { |n| "user#{n}@example.com" }
  end
end
