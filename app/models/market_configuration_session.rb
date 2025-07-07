# frozen_string_literal: true

# Session object for managing market configuration across multiple steps
class MarketConfigurationSession
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attribute :title, :string
  attribute :description, :string
  attribute :deadline, :datetime
  attribute :market_type, :string
  attribute :optional_document_ids, array: true, default: []

  validates :title, presence: true, length: { minimum: 3, maximum: 255 }
  validates :description, presence: true, length: { minimum: 10, maximum: 2000 }
  validates :deadline, presence: true
  validates :market_type, presence: true, inclusion: { in: %w[supplies services works] }

  validate :deadline_must_be_future
  validate :optional_documents_must_exist

  def initialize(attributes = {})
    super
    self.optional_document_ids ||= []
  end

  def valid_market_type?
    market_type.present? && %w[supplies services works].include?(market_type)
  end

  def to_h
    {
      title: title,
      description: description,
      deadline: deadline,
      market_type: market_type,
      optional_document_ids: optional_document_ids
    }
  end

  def mandatory_documents
    return Document.none unless valid_market_type?

    Document.mandatory_for_market_type(market_type)
  end

  def optional_documents
    return Document.none unless valid_market_type?

    Document.optional_for_market_type(market_type)
  end

  def selected_optional_documents
    return Document.none if optional_document_ids.blank?

    Document.where(id: optional_document_ids)
  end

  def all_required_documents
    mandatory_documents + selected_optional_documents
  end

  private

  def deadline_must_be_future
    return unless deadline.present?

    return unless deadline <= 1.hour.from_now

    errors.add(:deadline, 'must be at least 1 hour in the future')
  end

  def optional_documents_must_exist
    return if optional_document_ids.blank?

    existing_ids = Document.where(id: optional_document_ids).pluck(:id)
    invalid_ids = optional_document_ids.map(&:to_i) - existing_ids

    return unless invalid_ids.any?

    errors.add(:optional_document_ids, "contains invalid document IDs: #{invalid_ids.join(', ')}")
  end
end
