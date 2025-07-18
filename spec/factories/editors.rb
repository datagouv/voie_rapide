# frozen_string_literal: true

FactoryBot.define do
  factory :editor do
    name { 'MyString' }
    client_id { 'MyString' }
    client_secret { 'MyString' }
    authorized { false }
    active { false }
  end
end
