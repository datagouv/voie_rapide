# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Application, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:siret) }
    it { should validate_presence_of(:company_name) }

    it 'validates SIRET format' do
      application = build(:application, siret: '12345')
      expect(application).not_to be_valid
      expect(application.errors[:siret]).to include('must contain exactly 14 digits')
    end

    it 'accepts valid SIRET' do
      application = build(:application, siret: '12345678901234')
      expect(application).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:public_market) }
  end

  describe 'uniqueness' do
    it 'validates uniqueness of SIRET per public market' do
      public_market = create(:public_market)
      create(:application, siret: '12345678901234', public_market: public_market)

      duplicate_application = build(:application, siret: '12345678901234', public_market: public_market)
      expect(duplicate_application).not_to be_valid
    end

    it 'allows same SIRET for different public markets' do
      create(:application, siret: '12345678901234')
      application2 = build(:application, siret: '12345678901234')

      expect(application2).to be_valid
    end
  end

  describe 'status' do
    it 'has default status of in_progress' do
      application = build(:application)
      expect(application.status).to eq('in_progress')
    end
  end
end
