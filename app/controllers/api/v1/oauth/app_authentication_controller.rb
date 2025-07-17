# frozen_string_literal: true

module Api
  module V1
    module OAuth
      class AppAuthenticationController < BaseController
        before_action :authenticate_editor!, except: [:create]
        before_action :find_editor_by_credentials, only: [:create]

        # POST /api/v1/oauth/app_token
        # Client credentials flow for automated app-to-app authentication
        def create
          return render_authentication_error unless @editor&.authorized_and_active?

          result = AppAuthenticationService.new(@editor).authenticate

          if result.success?
            render json: {
              access_token: result.access_token,
              expires_in: result.expires_in,
              token_type: 'Bearer',
              scope: result.scope,
              created_at: Time.current.to_i
            }
          else
            render_authentication_error(result.error)
          end
        end

        # POST /api/v1/oauth/refresh_token
        # Refresh an existing access token
        def refresh
          result = TokenManagementService.new(@editor, current_access_token).refresh

          if result.success?
            render json: {
              access_token: result.access_token,
              expires_in: result.expires_in,
              token_type: 'Bearer',
              scope: result.scope,
              created_at: Time.current.to_i
            }
          else
            render_authentication_error(result.error)
          end
        end

        # GET /api/v1/oauth/app_status
        # Check app authentication status
        def status
          token_info = TokenManagementService.new(@editor, current_access_token).status

          render json: {
            authenticated: true,
            editor_id: @editor.id,
            editor_name: @editor.name,
            token_expires_at: token_info.expires_at,
            token_expires_in: token_info.expires_in,
            scopes: token_info.scopes,
            last_used_at: current_access_token.last_used_at
          }
        end

        private

        def find_editor_by_credentials
          client_id = request.headers['HTTP_AUTHORIZATION']&.split&.last ||
                      params[:client_id]
          client_secret = params[:client_secret]

          return render_authentication_error('Missing client credentials') unless client_id && client_secret

          @editor = Editor.find_by(client_id: client_id)
          return render_authentication_error('Invalid client credentials') unless @editor&.client_secret == client_secret

          @editor
        end

        def authenticate_editor!
          doorkeeper_authorize! :app_market_config, :app_market_read, :app_application_read
          @editor = Editor.find_by(client_id: doorkeeper_token.application.uid)
          render_authentication_error('Editor not found') unless @editor
        end

        def current_access_token
          doorkeeper_token
        end

        def render_authentication_error(message = 'Authentication failed')
          render json: {
            error: 'unauthorized',
            error_description: message
          }, status: :unauthorized
        end
      end
    end
  end
end
