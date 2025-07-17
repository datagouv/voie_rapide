# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PublicMarket, type: :model do
  describe 'validations' do
    subject { build(:public_market) }

    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:deadline) }
    it { should validate_presence_of(:market_type) }

    it 'validates uniqueness of fast_track_id' do
      existing_market = create(:public_market)
      duplicate_market = build(:public_market, fast_track_id: existing_market.fast_track_id)

      expect(duplicate_market).not_to be_valid
      expect(duplicate_market.errors[:fast_track_id]).to include('has already been taken')
    end
  end

  describe 'associations' do
    it { should belong_to(:editor) }
    it { should have_many(:applications).dependent(:destroy) }
    it { should have_many(:public_market_configurations).dependent(:destroy) }
  end

  describe 'callbacks' do
    it 'generates fast_track_id before validation on create' do
      public_market = build(:public_market, fast_track_id: nil)
      expect(public_market.fast_track_id).to be_nil

      public_market.validate
      expect(public_market.fast_track_id).to be_present
    end

    it 'does not overwrite existing fast_track_id' do
      existing_id = 'EXISTING_ID'
      public_market = build(:public_market, fast_track_id: existing_id)

      public_market.validate
      expect(public_market.fast_track_id).to eq(existing_id)
    end
  end

  describe 'scopes' do
    let!(:active_market) { create(:public_market, active: true) }
    let!(:inactive_market) { create(:public_market, active: false) }

    describe '.active' do
      it 'returns only active public markets' do
        expect(described_class.active).to include(active_market)
        expect(described_class.active).not_to include(inactive_market)
      end
    end
  end

  describe 'default values' do
    it 'has default active status of true' do
      public_market = build(:public_market)
      expect(public_market.active).to be true
    end
  end
end
