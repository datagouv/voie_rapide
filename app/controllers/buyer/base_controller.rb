# frozen_string_literal: true

module Buyer
  # Base controller for buyer (editor) functionality
  # Provides OAuth authentication and authorization for editor platforms
  class BaseController < ApplicationController
    before_action :authenticate_editor!
    before_action :ensure_editor_authorized!

    protected

    # Authenticate editor via Doorkeeper OAuth token
    def authenticate_editor!
      doorkeeper_authorize!
    end

    # Get current editor from OAuth token
    def current_editor
      @current_editor ||= find_current_editor
    end

    def find_current_editor
      return nil unless doorkeeper_token

      # Find editor by the application associated with the token
      application = doorkeeper_token.application
      Editor.find_by(client_id: application.uid) if application
    end

    # Ensure current editor is authorized and active
    def ensure_editor_authorized!
      return if current_editor&.authorized_and_active?

      render json: {
        error: 'Editor not authorized',
        message: 'Your editor platform is not authorized to access Fast Track'
      }, status: :forbidden
    end

    # Get current OAuth token
    def doorkeeper_token
      @doorkeeper_token ||= Doorkeeper::OAuth::Token.authenticate(
        request,
        *Doorkeeper.configuration.access_token_methods
      )
    end

    # Configure iframe-friendly responses
    def configure_iframe_response
      response.headers['X-Frame-Options'] = 'SAMEORIGIN'
      response.headers['Content-Security-Policy'] = "frame-ancestors 'self' #{current_editor&.callback_url}"
    end

    # Handle OAuth errors gracefully
    def doorkeeper_unauthorized_render_options(error:)
      {
        json: {
          error: 'OAuth authentication required',
          message: 'Valid access token required to access this resource',
          details: error.description
        },
        status: :unauthorized
      }
    end

    # Log buyer actions for audit trail
    def log_buyer_action(action, details = {})
      Rails.logger.info({
        buyer_action: action,
        editor_id: current_editor&.id,
        editor_name: current_editor&.name,
        timestamp: Time.current,
        details: details
      }.to_json)
    end
  end
end
