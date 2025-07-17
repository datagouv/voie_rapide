# frozen_string_literal: true

FactoryBot.define do
  factory :oauth_application, class: 'Doorkeeper::Application' do
    sequence(:name) { |n| "Test OAuth App #{n}" }
    sequence(:uid) { |n| "uid_#{n}_#{SecureRandom.hex(16)}" }
    sequence(:secret) { |n| "secret_#{n}_#{SecureRandom.hex(32)}" }
    redirect_uri { 'https://localhost:4000/callback' }
    scopes { 'app_market_config app_market_read app_application_read' }
    confidential { true }

    trait :public do
      confidential { false }
    end

    trait :with_limited_scopes do
      scopes { 'app_market_read' }
    end
  end
end
