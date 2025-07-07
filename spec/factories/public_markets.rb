# frozen_string_literal: true

FactoryBot.define do
  factory :public_market do
    association :editor
    title { 'Public Market Test' }
    description { 'Description of test public market' }
    deadline { 1.month.from_now }
    market_type { 'supplies' }
    active { true }

    trait :closed do
      deadline { 1.week.ago }
    end

    trait :inactive do
      active { false }
    end

    trait :services do
      market_type { 'services' }
    end

    trait :works do
      market_type { 'works' }
    end
  end
end
