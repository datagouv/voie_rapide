# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Document, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:nom) }
  end

  describe 'associations' do
    it { should have_many(:public_market_configurations).dependent(:destroy) }
    it { should have_many(:public_markets).through(:public_market_configurations) }
  end

  describe 'scopes' do
    let!(:obligatoire_document) { create(:document, obligatoire: true) }
    let!(:optionnel_document) { create(:document, obligatoire: false) }
    let!(:active_document) { create(:document, active: true) }
    let!(:inactive_document) { create(:document, active: false) }

    describe '.obligatoires' do
      it 'returns only obligatory documents' do
        expect(described_class.obligatoires).to include(obligatoire_document)
        expect(described_class.obligatoires).not_to include(optionnel_document)
      end
    end

    describe '.optionnels' do
      it 'returns only optional documents' do
        expect(described_class.optionnels).to include(optionnel_document)
        expect(described_class.optionnels).not_to include(obligatoire_document)
      end
    end

    describe '.active' do
      it 'returns only active documents' do
        expect(described_class.active).to include(active_document)
        expect(described_class.active).not_to include(inactive_document)
      end
    end

    describe '.par_type_marche' do
      it 'returns documents applicable to specific market type' do
        document = create(:document, type_marche: 'fournitures')
        expect(described_class.par_type_marche('fournitures')).to include(document)
      end

      it 'includes documents with nil type_marche (applicable to all)' do
        document = create(:document, type_marche: nil)
        expect(described_class.par_type_marche('fournitures')).to include(document)
      end
    end
  end

  describe '#obligatoire?' do
    it 'returns true when obligatoire is true' do
      document = build(:document, obligatoire: true)
      expect(document.obligatoire?).to be true
    end

    it 'returns false when obligatoire is false' do
      document = build(:document, obligatoire: false)
      expect(document.obligatoire?).to be false
    end
  end

  describe '#optionnel?' do
    it 'returns false when obligatoire is true' do
      document = build(:document, obligatoire: true)
      expect(document.optionnel?).to be false
    end

    it 'returns true when obligatoire is false' do
      document = build(:document, obligatoire: false)
      expect(document.optionnel?).to be true
    end
  end

  describe '#applicable_pour_type?' do
    it 'returns true when type_marche is nil' do
      document = build(:document, type_marche: nil)
      expect(document.applicable_pour_type?('fournitures')).to be true
    end

    it 'returns true when type_marche matches' do
      document = build(:document, type_marche: 'fournitures')
      expect(document.applicable_pour_type?('fournitures')).to be true
    end

    it 'returns false when type_marche does not match' do
      document = build(:document, type_marche: 'services')
      expect(document.applicable_pour_type?('fournitures')).to be false
    end
  end
end
