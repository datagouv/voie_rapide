# frozen_string_literal: true

class Application < ApplicationRecord
  belongs_to :public_market
  has_many_attached :documents

  validates :siret, presence: true, format: { with: /\A\d{14}\z/, message: 'must contain exactly 14 digits' }
  validates :company_name, presence: true
  validates :public_market_id, uniqueness: { scope: :siret }
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
    return if siret.blank?

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
    required_document_ids = required_document_ids_from_market
    return true if required_document_ids.empty?
    return false unless documents.attached?

    attached_document_ids = extract_attached_document_ids
    all_required_documents_present?(required_document_ids, attached_document_ids)
  end

  private

  def required_document_ids_from_market
    public_market.public_market_configurations
                 .where(required: true)
                 .pluck(:document_id)
  end

  def extract_attached_document_ids
    # Get the document IDs from the attached filenames
    # Filenames are in format: "document_id_siret.pdf"
    documents.map do |doc|
      doc.filename.to_s.split('_').first.to_i
    end.uniq
  end

  def all_required_documents_present?(required_ids, attached_ids)
    (required_ids - attached_ids).empty?
  end

  def submission_complete?
    submitted? && submission_id.present? && submitted_at.present?
  end

  def attestation_available?
    submission_complete? && attestation_path.present? && File.exist?(attestation_path)
  end
end
