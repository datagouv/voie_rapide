# frozen_string_literal: true

class Application < ApplicationRecord
  belongs_to :public_market
  has_many_attached :documents

  validates :siret, presence: true, format: { with: /\A\d{14}\z/, message: 'must contain exactly 14 digits' }
  validates :company_name, presence: true
  validates :public_market_id, uniqueness: { scope: :siret, message: 'An application already exists for this SIRET on this market' }
  validates :status, inclusion: { in: %w[in_progress submitted] }

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
end
