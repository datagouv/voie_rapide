# frozen_string_literal: true

FactoryBot.define do
  factory :access_token, class: 'Doorkeeper::AccessToken' do
    association :application, factory: :oauth_application
    sequence(:token) { |n| "token_#{n}_#{SecureRandom.hex(32)}" }
    scopes { 'market_config' }
    expires_in { 7200 }

    trait :expired do
      expires_in { -3600 }
    end

    trait :with_read_scope do
      scopes { 'market_read' }
    end

    trait :with_multiple_scopes do
      scopes { 'market_config market_read application_read' }
    end

    trait :revoked do
      revoked_at { 1.hour.ago }
    end
  end
end
