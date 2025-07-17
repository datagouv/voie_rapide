# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Buyer::MarketConfigurationsController, type: :controller do
  let(:application) { create(:oauth_application) }
  let(:editor) { create(:editor, :authorized_and_active, client_id: application.uid) }
  let(:access_token) { create(:access_token, application: application, scopes: 'market_config') }

  describe 'GET #new with auto-fill parameters' do
    before do
      # Ensure editor exists before any tests run
      editor
    end

    context 'with valid OAuth token and market data' do
      it 'processes and pre-fills market data correctly' do
        get :new, params: {
          access_token: access_token.token,
          callback_url: 'http://localhost:4000/callback',
          state: 'test_state',
          title: 'Test Market Auto-Fill',
          description: 'This is a test description',
          deadline: '2025-08-14T10:09:45Z'
        }

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(new_buyer_market_configuration_path)

        # Verify session contains pre-filled data
        expect(session[:market_configuration]).to be_present
        expect(session[:market_configuration]['title']).to eq('Test Market Auto-Fill')
        expect(session[:market_configuration]['description']).to eq('This is a test description')
        expect(session[:market_configuration]['deadline']).to be_present

        # Verify callback parameters are stored
        expect(session[:platform_callback]).to be_present
        expect(session[:platform_callback]['url']).to eq('http://localhost:4000/callback')
        expect(session[:platform_callback]['state']).to eq('test_state')
      end

      it 'handles special characters in market data' do
        get :new, params: {
          access_token: access_token.token,
          callback_url: 'http://localhost:4000/callback',
          state: 'test_state',
          title: 'Marché éàüñ & symbols! <test>',
          description: 'Test with special chars: éàüñ ßæø, symbols: !@#$%^&*()',
          deadline: '2025-08-14T10:09:45Z'
        }

        expect(response).to have_http_status(:redirect)

        expect(session[:market_configuration]['title']).to eq('Marché éàüñ & symbols! <test>')
        expect(session[:market_configuration]['description']).to eq('Test with special chars: éàüñ ßæø, symbols: !@#$%^&*()')
      end

      it 'handles missing deadline parameter' do
        get :new, params: {
          access_token: access_token.token,
          callback_url: 'http://localhost:4000/callback',
          state: 'test_state',
          title: 'Test Market Without Deadline',
          description: 'Test description'
        }

        expect(response).to have_http_status(:redirect)

        expect(session[:market_configuration]['title']).to eq('Test Market Without Deadline')
        expect(session[:market_configuration]['description']).to eq('Test description')
        expect(session[:market_configuration]['deadline']).to be_nil
      end

      it 'handles missing market data gracefully' do
        get :new, params: {
          access_token: access_token.token,
          callback_url: 'http://localhost:4000/callback',
          state: 'test_state'
        }

        expect(response).to have_http_status(:redirect)

        # Session should not contain market data
        expect(session[:market_configuration]).to be_nil
      end
    end

    context 'with invalid OAuth token' do
      it 'rejects invalid token' do
        get :new, params: {
          access_token: 'invalid_token',
          callback_url: 'http://localhost:4000/callback',
          state: 'test_state',
          title: 'Test Market',
          description: 'Test description'
        }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects expired token' do
        expired_token = create(:access_token,
                               application: application,
                               scopes: 'market_config',
                               expires_in: -3600)

        get :new, params: {
          access_token: expired_token.token,
          callback_url: 'http://localhost:4000/callback',
          state: 'test_state',
          title: 'Test Market',
          description: 'Test description'
        }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects token with wrong scopes' do
        wrong_scope_token = create(:access_token,
                                   application: application,
                                   scopes: 'read_only')

        get :new, params: {
          access_token: wrong_scope_token.token,
          callback_url: 'http://localhost:4000/callback',
          state: 'test_state',
          title: 'Test Market',
          description: 'Test description'
        }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'error scenarios' do
      it 'handles invalid deadline format' do
        get :new, params: {
          access_token: access_token.token,
          callback_url: 'http://localhost:4000/callback',
          state: 'test_state',
          title: 'Test Market',
          description: 'Test description',
          deadline: 'invalid-date'
        }

        # Should redirect and store other valid data but not invalid deadline
        expect(response).to have_http_status(:redirect)
        expect(session[:market_configuration]).to be_present
        expect(session[:market_configuration]['title']).to eq('Test Market')
        expect(session[:market_configuration]['description']).to eq('Test description')
        expect(session[:market_configuration]['deadline']).to be_nil
      end

      it 'handles extremely long parameters' do
        long_title = 'A' * 1000
        long_description = 'B' * 5000

        get :new, params: {
          access_token: access_token.token,
          callback_url: 'http://localhost:4000/callback',
          state: 'test_state',
          title: long_title,
          description: long_description,
          deadline: '2025-08-14T10:09:45Z'
        }

        expect(response).to have_http_status(:redirect)

        expect(session[:market_configuration]['title']).to eq(long_title)
        expect(session[:market_configuration]['description']).to eq(long_description)
      end

      it 'handles malicious input safely' do
        malicious_inputs = [
          "'; DROP TABLE markets; --",
          "admin' OR '1'='1",
          "<script>alert('xss')</script>",
          ("\x00" * 10).to_s
        ]

        malicious_inputs.each do |input|
          get :new, params: {
            access_token: access_token.token,
            callback_url: 'http://localhost:4000/callback',
            state: 'test_state',
            title: input,
            description: input,
            deadline: '2025-08-14T10:09:45Z'
          }

          expect(response).to have_http_status(:redirect)

          # Should store the input safely (Rails handles sanitization)
          expect(session[:market_configuration]['title']).to eq(input)
          expect(session[:market_configuration]['description']).to eq(input)
        end
      end
    end
  end

  describe 'MarketConfigurationSession validation' do
    it 'validates pre-filled data correctly' do
      market_config = MarketConfigurationSession.new(
        title: 'Test Market',
        description: 'Test description with sufficient length',
        deadline: 30.days.from_now,
        market_type: 'supplies'
      )

      expect(market_config).to be_valid
    end

    it 'validates minimum title length' do
      market_config = MarketConfigurationSession.new(
        title: 'AB', # Too short
        description: 'Test description with sufficient length',
        deadline: 30.days.from_now,
        market_type: 'supplies'
      )

      expect(market_config).not_to be_valid
      expect(market_config.errors[:title]).to be_present
    end

    it 'validates minimum description length' do
      market_config = MarketConfigurationSession.new(
        title: 'Valid Title',
        description: 'Too short', # Too short
        deadline: 30.days.from_now,
        market_type: 'supplies'
      )

      expect(market_config).not_to be_valid
      expect(market_config.errors[:description]).to be_present
    end

    it 'validates future deadline' do
      market_config = MarketConfigurationSession.new(
        title: 'Valid Title',
        description: 'Valid description with sufficient length',
        deadline: 1.hour.ago, # Past deadline
        market_type: 'supplies'
      )

      expect(market_config).not_to be_valid
      expect(market_config.errors[:deadline]).to be_present
    end

    it 'validates market type inclusion' do
      market_config = MarketConfigurationSession.new(
        title: 'Valid Title',
        description: 'Valid description with sufficient length',
        deadline: 30.days.from_now,
        market_type: 'invalid_type'
      )

      expect(market_config).not_to be_valid
      expect(market_config.errors[:market_type]).to be_present
    end
  end

  describe 'callback parameter storage' do
    before do
      # Ensure editor exists before any tests run
      editor
    end

    it 'stores callback parameters in session' do
      get :new, params: {
        access_token: access_token.token,
        callback_url: 'http://localhost:4000/callback',
        state: 'test_state_12345'
      }

      expect(response).to have_http_status(:redirect)
      expect(session[:platform_callback]).to be_present
      expect(session[:platform_callback]['url']).to eq('http://localhost:4000/callback')
      expect(session[:platform_callback]['state']).to eq('test_state_12345')
    end

    it 'handles missing callback parameters' do
      get :new, params: {
        access_token: access_token.token
      }

      expect(session[:platform_callback]).to be_nil
    end
  end
end
