# frozen_string_literal: true

class Document < ApplicationRecord
  has_many :public_market_configurations, dependent: :destroy
  has_many :public_markets, through: :public_market_configurations

  validates :nom, presence: true

  scope :mandatory, -> { where(obligatoire: true) }
  scope :optional, -> { where(obligatoire: false) }
  scope :active, -> { where(active: true) }
  scope :for_market_type, ->(type) { where(type_marche: [nil, type]) }

  # French scope names for compatibility with existing specs (using English scopes)
  scope :obligatoires, -> { mandatory }
  scope :optionnels, -> { optional }
  scope :par_type_marche, ->(type) { for_market_type(type) }

  # Combined scopes for market configuration
  scope :mandatory_for_market_type, ->(type) { mandatory.for_market_type(type).active }
  scope :optional_for_market_type, ->(type) { optional.for_market_type(type).active }

  def mandatory?
    obligatoire
  end

  def optional?
    !obligatoire
  end

  def applicable_for_type?(market_type)
    type_marche.nil? || type_marche == market_type
  end

  # French method names for compatibility with existing specs
  def obligatoire?
    obligatoire
  end

  def optionnel?
    !obligatoire
  end

  def applicable_pour_type?(market_type)
    type_marche.nil? || type_marche == market_type
  end
end
