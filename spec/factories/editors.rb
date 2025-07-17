# frozen_string_literal: true

FactoryBot.define do
  factory :editor do
    sequence(:name) { |n| "Editor #{n}" }
    sequence(:client_id) { |n| "client_id_#{n}" }
    sequence(:client_secret) { |n| "client_secret_#{n}" }
    callback_url { 'https://example.com/callback' }
    authorized { false }
    active { true }

    trait :authorized do
      authorized { true }
    end

    trait :inactive do
      active { false }
    end

    trait :authorized_and_active do
      authorized { true }
      active { true }
    end
  end
end
