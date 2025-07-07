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

  # OAuth integration with Doorkeeper
  def doorkeeper_application
    @doorkeeper_application ||= Doorkeeper::Application.find_by(uid: client_id)
  end

  def ensure_doorkeeper_application!
    return doorkeeper_application if doorkeeper_application

    create_doorkeeper_application!
  end

  def sync_to_doorkeeper!
    if doorkeeper_application
      update_doorkeeper_application!
    else
      create_doorkeeper_application!
    end
  end

  private

  def create_doorkeeper_application!
    Doorkeeper::Application.create!(
      name: name,
      uid: client_id,
      secret: client_secret,
      redirect_uri: callback_url,
      scopes: 'market_config market_read application_read'
    )
  end

  def update_doorkeeper_application!
    doorkeeper_application.update!(
      name: name,
      secret: client_secret,
      redirect_uri: callback_url,
      scopes: 'market_config market_read application_read'
    )
  end
end
