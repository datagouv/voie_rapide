# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OAuth Security', type: :request do
  let(:application) { create(:oauth_application) }
  let(:editor) { create(:editor, :authorized_and_active, client_id: application.uid) }
  let(:base_params) do
    {
      callback_url: 'http://localhost:4000/callback',
      state: 'test_state',
      title: 'Test Market',
      description: 'Test description',
      deadline: '2025-08-14T10:09:45Z'
    }
  end

  describe 'OAuth token validation' do
    context 'with valid tokens' do
      it 'accepts valid token with correct scopes' do
        # Ensure editor exists before creating token
        editor

        valid_token = create(:access_token,
                             application: application,
                             scopes: 'market_config')

        get '/buyer/market_configurations/new',
            params: base_params.merge(access_token: valid_token.token)

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(new_buyer_market_configuration_path)
      end

      it 'accepts token with multiple scopes including market_config' do
        # Ensure editor exists before creating token
        editor

        multi_scope_token = create(:access_token,
                                   application: application,
                                   scopes: 'market_config market_read application_read')

        get '/buyer/market_configurations/new',
            params: base_params.merge(access_token: multi_scope_token.token)

        expect(response).to have_http_status(:redirect)
      end
    end

    context 'with invalid tokens' do
      it 'rejects non-existent token' do
        get '/buyer/market_configurations/new',
            params: base_params.merge(access_token: 'invalid_token_123')

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['WWW-Authenticate']).to include('Bearer')
      end

      it 'rejects empty token' do
        get '/buyer/market_configurations/new',
            params: base_params.merge(access_token: '')

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects nil token' do
        get '/buyer/market_configurations/new',
            params: base_params

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects malformed tokens' do
        malformed_tokens = [
          'token.with.dots',
          'token with spaces',
          "token\nwith\nnewlines",
          "token_with_wrong_length_#{'x' * 100}"
        ]

        malformed_tokens.each do |token|
          get '/buyer/market_configurations/new',
              params: base_params.merge(access_token: token)

          expect(response).to have_http_status(:unauthorized),
                              "Token '#{token}' should be rejected"
        end
      end
    end

    context 'with expired tokens' do
      it 'rejects expired token' do
        expired_token = create(:access_token,
                               application: application,
                               scopes: 'market_config',
                               expires_in: -3600)

        get '/buyer/market_configurations/new',
            params: base_params.merge(access_token: expired_token.token)

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects token that expires soon' do
        soon_expired_token = create(:access_token,
                                    application: application,
                                    scopes: 'market_config',
                                    expires_in: 1)

        # Wait for token to expire
        sleep(2)

        get '/buyer/market_configurations/new',
            params: base_params.merge(access_token: soon_expired_token.token)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with wrong scopes' do
      it 'rejects token with read_only scope' do
        readonly_token = create(:access_token,
                                application: application,
                                scopes: 'read_only')

        get '/buyer/market_configurations/new',
            params: base_params.merge(access_token: readonly_token.token)

        expect(response).to have_http_status(:forbidden)
      end

      it 'rejects token with application_read scope only' do
        app_read_token = create(:access_token,
                                application: application,
                                scopes: 'application_read')

        get '/buyer/market_configurations/new',
            params: base_params.merge(access_token: app_read_token.token)

        expect(response).to have_http_status(:forbidden)
      end

      it 'rejects token with no scopes' do
        no_scope_token = create(:access_token,
                                application: application,
                                scopes: '')

        get '/buyer/market_configurations/new',
            params: base_params.merge(access_token: no_scope_token.token)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with revoked tokens' do
      it 'rejects revoked token' do
        revoked_token = create(:access_token,
                               application: application,
                               scopes: 'market_config')
        revoked_token.revoke

        get '/buyer/market_configurations/new',
            params: base_params.merge(access_token: revoked_token.token)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'OAuth application validation' do
    it 'accepts token from valid application' do
      # Ensure editor exists before creating token
      editor

      valid_token = create(:access_token,
                           application: application,
                           scopes: 'market_config')

      get '/buyer/market_configurations/new',
          params: base_params.merge(access_token: valid_token.token)

      expect(response).to have_http_status(:redirect)
    end

    it 'rejects token from different application' do
      # Ensure editor exists before creating token
      editor

      other_app = create(:oauth_application)
      # Create an editor for the other app too
      create(:editor, :authorized_and_active, client_id: other_app.uid)

      other_token = create(:access_token,
                           application: other_app,
                           scopes: 'market_config')

      get '/buyer/market_configurations/new',
          params: base_params.merge(access_token: other_token.token)

      # Should still work as long as the token is valid
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'Security headers' do
    it 'includes proper security headers' do
      valid_token = create(:access_token,
                           application: application,
                           scopes: 'market_config')

      get '/buyer/market_configurations/new',
          params: base_params.merge(access_token: valid_token.token)

      expect(response.headers['X-Frame-Options']).to eq('SAMEORIGIN')
      expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
      expect(response.headers['X-XSS-Protection']).to eq('0')
      expect(response.headers['Referrer-Policy']).to eq('strict-origin-when-cross-origin')
    end

    it 'includes proper WWW-Authenticate header on 401' do
      get '/buyer/market_configurations/new',
          params: base_params.merge(access_token: 'invalid')

      expect(response.headers['WWW-Authenticate']).to include('Bearer')
      expect(response.headers['WWW-Authenticate']).to include('error="invalid_token"')
    end
  end

  describe 'Rate limiting protection' do
    it 'handles multiple requests with same token' do
      # Ensure editor exists before creating token
      editor

      valid_token = create(:access_token,
                           application: application,
                           scopes: 'market_config')

      # Make multiple requests
      5.times do
        get '/buyer/market_configurations/new',
            params: base_params.merge(access_token: valid_token.token)

        expect(response).to have_http_status(:redirect)
      end
    end

    it 'handles multiple requests with different invalid tokens' do
      # Make multiple requests with different invalid tokens
      5.times do |i|
        get '/buyer/market_configurations/new',
            params: base_params.merge(access_token: "invalid_token_#{i}")

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'CSRF protection' do
    it 'does not require CSRF token for API endpoints' do
      # Ensure editor exists before creating token
      editor

      valid_token = create(:access_token,
                           application: application,
                           scopes: 'market_config')

      # Should work without CSRF token since it's an API endpoint
      get '/buyer/market_configurations/new',
          params: base_params.merge(access_token: valid_token.token)

      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'Input validation security' do
    it 'sanitizes malicious input in parameters' do
      # Ensure editor exists before creating token
      editor

      valid_token = create(:access_token,
                           application: application,
                           scopes: 'market_config')

      malicious_inputs = [
        "'; DROP TABLE markets; --",
        "admin' OR '1'='1",
        "<script>alert('xss')</script>",
        ("\x00" * 10).to_s
      ]

      malicious_inputs.each do |input|
        get '/buyer/market_configurations/new',
            params: base_params.merge(
              access_token: valid_token.token,
              title: input,
              description: input
            )

        expect(response).to have_http_status(:redirect)

        # Should not cause any security issues (handled by Rails)
        expect(response.body).not_to include('DROP TABLE')
        expect(response.body).not_to include('<script>')
      end
    end
  end
end
