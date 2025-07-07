# frozen_string_literal: true

class Document < ApplicationRecord
  has_many :public_market_configurations, dependent: :destroy
  has_many :public_markets, through: :public_market_configurations

  validates :nom, presence: true
  validates :categorie, presence: true
  validates :categorie, inclusion: { in: %w[administrative technical financial legal administratif technique financier juridique] }

  scope :mandatory, -> { where(obligatoire: true) }
  scope :optional, -> { where(obligatoire: false) }
  scope :active, -> { where(active: true) }
  scope :by_category, ->(category) { where(categorie: category) }
  scope :for_market_type, ->(type) { where(type_marche: [nil, type]) }

  # French scope names for compatibility with existing specs
  scope :obligatoires, -> { where(obligatoire: true) }
  scope :optionnels, -> { where(obligatoire: false) }
  scope :par_categorie, ->(category) { where(categorie: category) }
  scope :par_type_marche, ->(type) { where(type_marche: [nil, type]) }

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
