# frozen_string_literal: true

module OAuth
  # Service to handle OAuth authentication flow for editors
  class EditorAuthenticationService
    def initialize(editor)
      @editor = editor
    end

    def generate_authorization_url(state: nil, redirect_uri: nil)
      ensure_editor_authorized!
      ensure_doorkeeper_application!

      # Build OAuth authorization URL
      params = {
        client_id: @editor.client_id,
        response_type: 'code',
        redirect_uri: redirect_uri || @editor.callback_url,
        scope: 'market_config',
        state: state
      }

      "#{base_oauth_url}/oauth/authorize?#{params.to_query}"
    end

    def exchange_code_for_token(authorization_code, redirect_uri: nil)
      ensure_editor_authorized!

      # Exchange authorization code for access token
      response = oauth_client.auth_code.get_token(
        authorization_code,
        redirect_uri: redirect_uri || @editor.callback_url
      )

      {
        access_token: response.token,
        expires_in: response.expires_in,
        scope: response.params['scope']
      }
    rescue OAuth2::Error => e
      Rails.logger.error "OAuth token exchange failed for editor #{@editor.name}: #{e.message}"
      raise StandardError, "OAuth authentication failed: #{e.message}"
    end

    def valid_token?(access_token)
      # Validate access token with Doorkeeper
      doorkeeper_token = Doorkeeper::AccessToken.find_by(token: access_token)

      return false unless doorkeeper_token
      return false if doorkeeper_token.expired?
      return false if doorkeeper_token.revoked?

      true
    end

    private

    attr_reader :editor

    def ensure_editor_authorized!
      return if @editor.authorized_and_active?

      raise StandardError, "Editor #{@editor.name} is not authorized or active"
    end

    def ensure_doorkeeper_application!
      @editor.ensure_doorkeeper_application!
    end

    def oauth_client
      @oauth_client ||= OAuth2::Client.new(
        @editor.client_id,
        @editor.client_secret,
        site: base_oauth_url,
        authorize_url: '/oauth/authorize',
        token_url: '/oauth/token'
      )
    end

    def base_oauth_url
      # In production, this should be the actual Fast Track URL
      Rails.application.routes.url_helpers.root_url.chomp('/')
    end
  end
end
