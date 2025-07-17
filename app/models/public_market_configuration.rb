# frozen_string_literal: true

class PublicMarketConfiguration < ApplicationRecord
  belongs_to :public_market
  belongs_to :document

  validates :public_market_id, uniqueness: { scope: :document_id }

  scope :required, -> { where(required: true) }
  scope :optional, -> { where(required: false) }
  scope :for_market, ->(market) { where(public_market: market) }
  scope :for_document, ->(document) { where(document: document) }

  def required?
    required
  end

  def optional?
    !required
  end
end
