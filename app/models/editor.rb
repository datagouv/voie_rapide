# frozen_string_literal: true

class Editor < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :client_id, presence: true, uniqueness: true
  validates :client_secret, presence: true
  validates :callback_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }

  scope :authorized, -> { where(authorized: true) }
  scope :active, -> { where(active: true) }
  scope :authorized_and_active, -> { authorized.active }
  scope :app_authentication_enabled, -> { where(app_authentication_enabled: true) }
  scope :app_authentication_ready, -> { authorized_and_active.app_authentication_enabled }

  has_many :public_markets, dependent: :destroy

  def authorized_and_active?
    authorized? && active?
  end

  def app_authentication_ready?
    authorized_and_active? && app_authentication_enabled?
  end

  def app_token_valid?
    app_token_expires_at.present? && app_token_expires_at > Time.current
  end

  def app_token_expired?
    !app_token_valid?
  end

  def update_app_token_usage!
    update!(app_token_last_used_at: Time.current)
  end

  def record_app_token_expiry(expires_at)
    update!(app_token_expires_at: expires_at)
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
      scopes: 'app_market_config app_market_read app_application_read'
    )
  end

  def update_doorkeeper_application!
    doorkeeper_application.update!(
      name: name,
      secret: client_secret,
      redirect_uri: callback_url,
      scopes: 'app_market_config app_market_read app_application_read'
    )
  end
end
