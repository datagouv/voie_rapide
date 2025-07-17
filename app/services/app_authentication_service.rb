# frozen_string_literal: true

# Service to handle client credentials OAuth flow for automated app-to-app authentication
class AppAuthenticationService
  def initialize(editor)
    @editor = editor
  end

  def authenticate
    return Result.failure('Editor not ready for app authentication') unless @editor.app_authentication_ready?

    begin
      token_response = request_client_credentials_token
      record_token_expiry(token_response)
      build_success_result(token_response)
    rescue OAuth2::Error => e
      handle_oauth_error(e)
    rescue StandardError => e
      handle_standard_error(e)
    end
  end

  private

  def record_token_expiry(token_response)
    @editor.record_app_token_expiry(token_response.expires_at)
  end

  def build_success_result(token_response)
    Result.success(
      access_token: token_response.token,
      expires_in: token_response.expires_in,
      expires_at: token_response.expires_at,
      scope: token_response.scopes.join(' ')
    )
  end

  def handle_oauth_error(error)
    Rails.logger.error "OAuth client credentials failed for editor #{@editor.name}: #{error.message}"
    Result.failure("Authentication failed: #{error.description}")
  end

  def handle_standard_error(error)
    Rails.logger.error "App authentication error for editor #{@editor.name}: #{error.message}"
    Result.failure("Authentication failed: #{error.message}")
  end

  def request_client_credentials_token
    oauth_client.client_credentials.get_token(
      scope: app_scopes.join(' ')
    )
  end

  def oauth_client
    @oauth_client ||= OAuth2::Client.new(
      @editor.client_id,
      @editor.client_secret,
      site: base_url,
      authorize_url: '/oauth/authorize',
      token_url: '/oauth/token'
    )
  end

  def app_scopes
    %w[app_market_config app_market_read app_application_read]
  end

  def base_url
    # In production, this should be the actual Fast Track URL
    # For now, use the application's own URL for self-authentication
    Rails.application.routes.url_helpers.root_url.chomp('/')
  end

  # Result object for service responses
  class Result
    attr_reader :data, :error

    def initialize(success:, data: nil, error: nil)
      @success = success
      @data = data
      @error = error
    end

    def success?
      @success
    end

    def failure?
      !@success
    end

    def access_token
      @data[:access_token] if success?
    end

    def expires_in
      @data[:expires_in] if success?
    end

    def expires_at
      @data[:expires_at] if success?
    end

    def scope
      @data[:scope] if success?
    end

    def self.success(data = {})
      new(success: true, data: data)
    end

    def self.failure(error)
      new(success: false, error: error)
    end
  end
end
