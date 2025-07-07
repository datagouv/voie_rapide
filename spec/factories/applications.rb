# frozen_string_literal: true

FactoryBot.define do
  factory :application do
    association :public_market
    sequence(:siret) { |n| format('%014d', n) }
    company_name { 'Test Company' }
    email { 'test@example.com' }
    status { 'in_progress' }
    form_data { {} }

    trait :submitted do
      status { 'submitted' }
      submitted_at { Time.current }
    end

    trait :with_attestation do
      attestation_path { '/path/to/attestation.pdf' }
    end

    trait :with_dossier_zip do
      dossier_zip_path { '/path/to/dossier.zip' }
    end

    trait :with_form_data do
      form_data do
        {
          'manager_name' => 'John Doe',
          'phone' => '0123456789',
          'address' => '123 Peace Street, 75001 Paris'
        }
      end
    end
  end
end
