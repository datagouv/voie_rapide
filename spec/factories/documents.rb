# frozen_string_literal: true

FactoryBot.define do
  factory :document do
    sequence(:nom) { |n| "Document #{n}" }
    description { 'Description du document' }
    obligatoire { false }
    categorie { 'administrative' }
    type_marche { nil }
    active { true }

    trait :obligatoire do
      obligatoire { true }
    end

    trait :technical do
      categorie { 'technical' }
    end

    trait :financial do
      categorie { 'financial' }
    end

    trait :legal do
      categorie { 'legal' }
    end

    trait :for_services do
      type_marche { 'services' }
    end

    trait :for_supplies do
      type_marche { 'supplies' }
    end

    trait :for_works do
      type_marche { 'works' }
    end

    trait :inactive do
      active { false }
    end
  end
end
