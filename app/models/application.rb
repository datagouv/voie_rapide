# frozen_string_literal: true

class Application < ApplicationRecord
  belongs_to :public_market
  has_many_attached :documents

  validates :siret, presence: true, format: { with: /\A\d{14}\z/, message: 'must contain exactly 14 digits' }
  validates :company_name, presence: true
  validates :public_market_id, uniqueness: { scope: :siret, message: 'An application already exists for this SIRET on this market' }
  validates :status, inclusion: { in: %w[in_progress submitted] }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, if: :submitted?
  validates :contact_person, presence: true, if: :submitted?

  scope :submitted, -> { where(status: 'submitted') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :for_market, ->(market) { where(public_market: market) }

  serialize :form_data, coder: JSON

  def submitted?
    status == 'submitted'
  end

  def in_progress?
    status == 'in_progress'
  end

  def submit!
    update!(
      status: 'submitted',
      submitted_at: Time.current
    )
  end

  def formatted_siret
    return unless siret.present?

    siret.gsub(/(\d{3})(\d{3})(\d{3})(\d{5})/, '\1 \2 \3 \4')
  end

  def form_complete?
    return false unless email.present? && contact_person.present?

    all_required_documents_attached?
  end

  def ready_for_submission?
    form_complete? && in_progress?
  end

  def all_required_documents_attached?
    required_document_ids = public_market.public_market_configurations
                                         .where(required: true)
                                         .pluck(:document_id)

    return true if required_document_ids.empty?

    # Check if all required documents are attached
    # This is a simplified check for MVP
    documents.attached? && required_document_ids.count <= documents.count
  end

  def submission_complete?
    submitted? && submission_id.present? && submitted_at.present?
  end

  def attestation_available?
    submission_complete? && attestation_path.present? && File.exist?(attestation_path)
  end
end
