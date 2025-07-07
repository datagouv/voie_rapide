# frozen_string_literal: true

class Editor < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :client_id, presence: true, uniqueness: true
  validates :client_secret, presence: true
  validates :callback_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }

  scope :authorized, -> { where(authorized: true) }
  scope :active, -> { where(active: true) }
  scope :authorized_and_active, -> { authorized.active }

  has_many :public_markets, dependent: :destroy

  def authorized_and_active?
    authorized? && active?
  end
end
