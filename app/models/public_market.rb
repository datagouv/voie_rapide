# frozen_string_literal: true

class PublicMarket < ApplicationRecord
  belongs_to :editor
  has_many :applications, dependent: :destroy
  has_many :public_market_configurations, dependent: :destroy
  has_many :documents, through: :public_market_configurations

  validates :title, presence: true
  validates :deadline, presence: true
  validates :fast_track_id, presence: true, uniqueness: true
  validates :market_type, presence: true

  scope :active, -> { where(active: true) }
  scope :open, -> { where('deadline > ?', Time.current) }
  scope :closed, -> { where('deadline <= ?', Time.current) }

  before_validation :generate_fast_track_id, on: :create

  def open?
    deadline > Time.current
  end

  def closed?
    !open?
  end

  def active_and_open?
    active? && open?
  end

  private

  def generate_fast_track_id
    return if fast_track_id.present?

    loop do
      self.fast_track_id = SecureRandom.hex(16)
      break unless self.class.exists?(fast_track_id: fast_track_id)
    end
  end
end
