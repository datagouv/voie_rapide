# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PublicMarketConfiguration, type: :model do
  describe 'associations' do
    it { should belong_to(:public_market) }
    it { should belong_to(:document) }
  end

  describe 'validations' do
    it 'validates uniqueness of document per public market' do
      public_market = create(:public_market)
      document = create(:document)
      create(:public_market_configuration, public_market: public_market, document: document)

      duplicate_config = build(:public_market_configuration, public_market: public_market, document: document)
      expect(duplicate_config).not_to be_valid
    end

    it 'allows same document for different public markets' do
      document = create(:document)
      create(:public_market_configuration, document: document)
      config2 = build(:public_market_configuration, document: document)

      expect(config2).to be_valid
    end
  end

  describe 'scopes' do
    let!(:required_config) { create(:public_market_configuration, required: true) }
    let!(:optional_config) { create(:public_market_configuration, required: false) }

    describe '.required' do
      it 'returns only required configurations' do
        expect(described_class.required).to include(required_config)
        expect(described_class.required).not_to include(optional_config)
      end
    end

    describe '.optional' do
      it 'returns only optional configurations' do
        expect(described_class.optional).to include(optional_config)
        expect(described_class.optional).not_to include(required_config)
      end
    end
  end

  describe 'default values' do
    it 'has default required status of true' do
      config = build(:public_market_configuration)
      expect(config.required).to be true
    end
  end
end
