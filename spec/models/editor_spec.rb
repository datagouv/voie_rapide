# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Editor, type: :model do
  subject { build(:editor) }

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_presence_of(:client_id) }
    it { should validate_uniqueness_of(:client_id) }
    it { should validate_presence_of(:client_secret) }
    it { should validate_presence_of(:callback_url) }

    it 'validates callback_url format' do
      editor = build(:editor, callback_url: 'invalid-url')
      expect(editor).not_to be_valid
      expect(editor.errors[:callback_url]).to be_present
    end

    it 'accepts valid HTTP URLs' do
      editor = build(:editor, callback_url: 'http://example.com/callback')
      expect(editor).to be_valid
    end

    it 'accepts valid HTTPS URLs' do
      editor = build(:editor, callback_url: 'https://example.com/callback')
      expect(editor).to be_valid
    end
  end

  describe 'associations' do
    it { should have_many(:public_markets).dependent(:destroy) }
  end

  describe 'scopes' do
    let!(:authorized_editor) { create(:editor, authorized: true, active: true) }
    let!(:unauthorized_editor) { create(:editor, authorized: false, active: true) }
    let!(:inactive_editor) { create(:editor, authorized: true, active: false) }

    describe '.authorized' do
      it 'returns only authorized editors' do
        expect(described_class.authorized).to include(authorized_editor)
        expect(described_class.authorized).not_to include(unauthorized_editor)
      end
    end

    describe '.active' do
      it 'returns only active editors' do
        expect(described_class.active).to include(authorized_editor)
        expect(described_class.active).not_to include(inactive_editor)
      end
    end

    describe '.authorized_and_active' do
      it 'returns only authorized and active editors' do
        expect(described_class.authorized_and_active).to include(authorized_editor)
        expect(described_class.authorized_and_active).not_to include(unauthorized_editor)
        expect(described_class.authorized_and_active).not_to include(inactive_editor)
      end
    end
  end

  describe '#authorized_and_active?' do
    it 'returns true when both authorized and active' do
      editor = build(:editor, authorized: true, active: true)
      expect(editor.authorized_and_active?).to be true
    end

    it 'returns false when not authorized' do
      editor = build(:editor, authorized: false, active: true)
      expect(editor.authorized_and_active?).to be false
    end

    it 'returns false when not active' do
      editor = build(:editor, authorized: true, active: false)
      expect(editor.authorized_and_active?).to be false
    end
  end
end
