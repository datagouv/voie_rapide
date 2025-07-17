# frozen_string_literal: true

# Service to handle access token management for editor applications
class TokenManagementService
  def initialize(editor, access_token = nil)
    @editor = editor
    @access_token = access_token
  end

  def refresh
    return AppAuthenticationService::Result.failure('Editor not ready for app authentication') unless @editor.app_authentication_ready?

    begin
      # For client credentials flow, we just request a new token
      # (refresh tokens are not typically used with client credentials)
      service = AppAuthenticationService.new(@editor)
      service.authenticate
    rescue StandardError => e
      Rails.logger.error "Token refresh error for editor #{@editor.name}: #{e.message}"
      AppAuthenticationService::Result.failure("Token refresh failed: #{e.message}")
    end
  end

  def status
    return nil unless @access_token

    doorkeeper_token = Doorkeeper::AccessToken.find_by(token: @access_token.token)
    return nil unless doorkeeper_token

    TokenStatus.new(
      expires_at: doorkeeper_token.expires_at,
      expires_in: doorkeeper_token.expires_in,
      scopes: doorkeeper_token.scopes.to_a,
      last_used_at: doorkeeper_token.last_used_at,
      valid: !doorkeeper_token.expired? && !doorkeeper_token.revoked?
    )
  end

  def revoke
    return false unless @access_token

    begin
      doorkeeper_token = Doorkeeper::AccessToken.find_by(token: @access_token.token)
      return false unless doorkeeper_token

      doorkeeper_token.revoke
      @editor.update!(app_token_expires_at: nil)
      true
    rescue StandardError => e
      Rails.logger.error "Token revocation error for editor #{@editor.name}: #{e.message}"
      false
    end
  end

  def cleanup_expired_tokens
    # Clean up expired tokens for this editor
    editor_application = @editor.doorkeeper_application
    return unless editor_application

    expired_tokens = Doorkeeper::AccessToken
                     .where(application: editor_application)
                     .where('expires_at < ?', Time.current)
                     .where(revoked_at: nil)

    expired_tokens.each(&:revoke)

    Rails.logger.info "Cleaned up #{expired_tokens.count} expired tokens for editor #{@editor.name}"
  end

  # Token status object
  class TokenStatus
    attr_reader :expires_at, :expires_in, :scopes, :last_used_at, :valid

    def initialize(expires_at:, expires_in:, scopes:, last_used_at:, valid:)
      @expires_at = expires_at
      @expires_in = expires_in
      @scopes = scopes
      @last_used_at = last_used_at
      @valid = valid
    end

    def expired?
      !valid
    end

    def expires_soon?(threshold = 10.minutes)
      expires_at && expires_at < threshold.from_now
    end
  end
end
