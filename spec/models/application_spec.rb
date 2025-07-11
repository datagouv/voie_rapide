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

  describe '#all_required_documents_attached?' do
    let(:application) { create(:application) }
    let(:required_document) { create(:document, :obligatoire) }
    let(:optional_document) { create(:document) } # Default is optional (obligatoire: false)

    before do
      create(:public_market_configuration, public_market: application.public_market, document: required_document, required: true)
      create(:public_market_configuration, public_market: application.public_market, document: optional_document, required: false)
    end

    context 'when no required documents exist' do
      before do
        application.public_market.public_market_configurations.where(required: true).destroy_all
      end

      it 'returns true' do
        expect(application.all_required_documents_attached?).to be true
      end
    end

    context 'when required documents exist but none are attached' do
      it 'returns false' do
        expect(application.all_required_documents_attached?).to be false
      end
    end

    context 'when all required documents are attached' do
      before do
        # Simulate document attachment with correct filename format
        application.documents.attach(
          io: StringIO.new('test content'),
          filename: "#{required_document.id}_#{application.siret}.pdf",
          content_type: 'application/pdf'
        )
      end

      it 'returns true' do
        expect(application.all_required_documents_attached?).to be true
      end
    end

    context 'when only some required documents are attached' do
      let(:another_required_document) { create(:document, :obligatoire) }

      before do
        create(:public_market_configuration, public_market: application.public_market, document: another_required_document, required: true)

        # Attach only one of the required documents
        application.documents.attach(
          io: StringIO.new('test content'),
          filename: "#{required_document.id}_#{application.siret}.pdf",
          content_type: 'application/pdf'
        )
      end

      it 'returns false' do
        expect(application.all_required_documents_attached?).to be false
      end
    end
  end
end
