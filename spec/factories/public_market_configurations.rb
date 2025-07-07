# frozen_string_literal: true

FactoryBot.define do
  factory :public_market_configuration do
    association :public_market
    association :document
    required { true }

    trait :optional do
      required { false }
    end
  end
end
