# frozen_string_literal: true

# Service to monitor and manage editor app authentication status
class EditorAppStatusService
  def initialize(editor)
    @editor = editor
  end

  def check_status
    unless @editor.app_authentication_ready?
      return AppStatus.new(
        editor: @editor,
        status: :not_ready,
        message: 'Editor not ready for app authentication'
      )
    end

    # Check if we have a valid token
    current_token = find_current_token

    if current_token&.valid?
      @editor.update_app_token_usage!
      AppStatus.new(
        editor: @editor,
        status: :authenticated,
        message: 'App authentication active',
        token_info: TokenManagementService.new(@editor, current_token).status
      )
    elsif current_token&.expired?
      AppStatus.new(
        editor: @editor,
        status: :token_expired,
        message: 'App token expired, refresh required'
      )
    else
      AppStatus.new(
        editor: @editor,
        status: :not_authenticated,
        message: 'No valid app token found'
      )
    end
  end

  def auto_refresh_if_needed
    status = check_status

    return status unless status.needs_refresh?

    Rails.logger.info "Auto-refreshing token for editor #{@editor.name}"

    result = TokenManagementService.new(@editor).refresh

    if result.success?
      AppStatus.new(
        editor: @editor,
        status: :authenticated,
        message: 'App token auto-refreshed successfully'
      )
    else
      AppStatus.new(
        editor: @editor,
        status: :refresh_failed,
        message: "Token refresh failed: #{result.error}"
      )
    end
  end

  def self.check_all_editors
    Editor.app_authentication_ready.find_each do |editor|
      service = new(editor)
      status = service.check_status

      Rails.logger.info "Editor #{editor.name} status: #{status.status} - #{status.message}"

      # Auto-refresh if token expires soon
      service.auto_refresh_if_needed if status.token_expires_soon?
    end
  end

  private

  def find_current_token
    application = @editor.doorkeeper_application
    return nil unless application

    # Find the most recent valid token
    Doorkeeper::AccessToken
      .where(application: application)
      .where('expires_at > ?', Time.current)
      .where(revoked_at: nil)
      .order(created_at: :desc)
      .first
  end

  # App status object
  class AppStatus
    attr_reader :editor, :status, :message, :token_info

    def initialize(editor:, status:, message:, token_info: nil)
      @editor = editor
      @status = status
      @message = message
      @token_info = token_info
    end

    def authenticated?
      status == :authenticated
    end

    def needs_refresh?
      %i[token_expired not_authenticated].include?(status)
    end

    def token_expires_soon?(threshold = 10.minutes)
      return false unless token_info

      token_info.expires_soon?(threshold)
    end

    def to_h
      {
        editor_id: editor.id,
        editor_name: editor.name,
        status: status,
        message: message,
        token_info: token_info_hash
      }
    end

    private

    def token_info_hash
      return nil unless token_info

      {
        expires_at: token_info.expires_at,
        expires_in: token_info.expires_in,
        scopes: token_info.scopes,
        last_used_at: token_info.last_used_at,
        valid: token_info.valid
      }
    end
  end
end
