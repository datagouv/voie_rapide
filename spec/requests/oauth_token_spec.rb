# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OAuth Token', type: :request do
  let(:editor) do
    Editor.create!(
      name: 'Test Editor',
      client_id: 'test_client_id',
      client_secret: 'test_client_secret',
      authorized: true,
      active: true
    )
  end

  before do
    # Ensure the Doorkeeper application is created
    editor.ensure_doorkeeper_application!
  end

  describe 'POST /oauth/token' do
    context 'with valid client credentials' do
      it 'returns an access token' do
        post '/oauth/token', params: {
          grant_type: 'client_credentials',
          client_id: editor.client_id,
          client_secret: editor.client_secret,
          scope: 'api_access'
        }

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['access_token']).to be_present
        expect(json_response['token_type']).to eq('Bearer')
        expect(json_response['expires_in']).to eq(86_400) # 24 hours
        expect(json_response['scope']).to eq('api_access')
      end
    end

    context 'with invalid client credentials' do
      it 'returns unauthorized error' do
        post '/oauth/token', params: {
          grant_type: 'client_credentials',
          client_id: 'invalid_id',
          client_secret: 'invalid_secret'
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    # TODO: Add validation for unauthorized/inactive editors
    # The endpoint currently works but needs additional validation
    # to check editor authorization status before issuing tokens
  end
end
