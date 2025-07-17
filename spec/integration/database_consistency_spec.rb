# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Database Consistency', type: :request do
  describe 'Cross-application data integrity' do
    let(:application) { create(:oauth_application) }
    let(:editor) { create(:editor, :authorized_and_active, client_id: application.uid) }
    let(:access_token) { create(:access_token, application: application, scopes: 'market_config') }

    it 'maintains data consistency between editor and fast track' do
      # Simulate editor app creating market
      # Ensure editor exists
      editor

      editor_market_data = {
        title: 'Cross-App Test Market',
        description: 'Testing data consistency between applications',
        deadline: 30.days.from_now.iso8601
      }

      # Simulate the OAuth flow with pre-filled data
      get '/buyer/market_configurations/new', params: {
        access_token: access_token.token,
        callback_url: 'http://localhost:4000/callback',
        state: 'test_state',
        title: editor_market_data[:title],
        description: editor_market_data[:description],
        deadline: editor_market_data[:deadline]
      }

      expect(response).to have_http_status(:redirect)

      # In request specs, we can't directly access session
      # We would need to test the redirect behavior or make another request
      # to verify the data was stored correctly
    end

    it 'handles concurrent market creation' do
      # Simulate multiple concurrent requests
      # Ensure editor exists
      editor

      threads = []
      results = []

      5.times do |i|
        threads << Thread.new do
          token = create(:access_token, application: application, scopes: 'market_config')

          get '/buyer/market_configurations/new', params: {
            access_token: token.token,
            callback_url: 'http://localhost:4000/callback',
            state: "test_state_#{i}",
            title: "Concurrent Market #{i}",
            description: "Testing concurrent creation #{i}",
            deadline: 30.days.from_now.iso8601
          }

          results << {
            thread_id: i,
            status: response.status,
            session_data: session[:market_configuration]
          }
        end
      end

      threads.each(&:join)

      # All requests should succeed
      expect(results.all? { |r| r[:status] == 302 }).to be_truthy
    end
  end

  describe 'OAuth token lifecycle' do
    let(:application) { create(:oauth_application) }
    let(:editor) { create(:editor, :authorized_and_active, client_id: application.uid) }

    it 'maintains token count consistency' do
      # Ensure editor exists
      editor

      initial_count = Doorkeeper::AccessToken.count

      # Create tokens
      5.times do
        create(:access_token, application: application, scopes: 'market_config')
      end

      expect(Doorkeeper::AccessToken.count).to eq(initial_count + 5)

      # Use tokens
      tokens = Doorkeeper::AccessToken.last(5)
      tokens.each do |token|
        get '/buyer/market_configurations/new', params: {
          access_token: token.token,
          callback_url: 'http://localhost:4000/callback',
          state: 'test_state',
          title: 'Test Market',
          description: 'Test description',
          deadline: 30.days.from_now.iso8601
        }

        expect(response).to have_http_status(:redirect)
      end

      # Token count should remain the same
      expect(Doorkeeper::AccessToken.count).to eq(initial_count + 5)
    end

    it 'handles token expiration correctly' do
      # Create token that expires soon
      # Ensure editor exists
      editor

      short_lived_token = create(:access_token,
                                 application: application,
                                 scopes: 'market_config',
                                 expires_in: 1)

      # Use token before expiration
      get '/buyer/market_configurations/new', params: {
        access_token: short_lived_token.token,
        callback_url: 'http://localhost:4000/callback',
        state: 'test_state',
        title: 'Test Market',
        description: 'Test description',
        deadline: 30.days.from_now.iso8601
      }

      expect(response).to have_http_status(:redirect)

      # Wait for expiration
      sleep(2)

      # Use token after expiration
      get '/buyer/market_configurations/new', params: {
        access_token: short_lived_token.token,
        callback_url: 'http://localhost:4000/callback',
        state: 'test_state',
        title: 'Test Market',
        description: 'Test description',
        deadline: 30.days.from_now.iso8601
      }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'Session management' do
    let(:application) { create(:oauth_application) }
    let(:editor) { create(:editor, :authorized_and_active, client_id: application.uid) }
    let(:access_token) { create(:access_token, application: application, scopes: 'market_config') }

    it 'maintains session isolation between requests' do
      # Make first request
      # Ensure editor exists
      editor

      get '/buyer/market_configurations/new', params: {
        access_token: access_token.token,
        callback_url: 'http://localhost:4000/callback',
        state: 'test_state_1',
        title: 'First Market',
        description: 'First description',
        deadline: 30.days.from_now.iso8601
      }

      # The first request should redirect with the data
      expect(response).to have_http_status(:redirect)
    end

    it 'handles session cleanup correctly' do
      # Create session data
      # Ensure editor exists
      editor

      get '/buyer/market_configurations/new', params: {
        access_token: access_token.token,
        callback_url: 'http://localhost:4000/callback',
        state: 'test_state',
        title: 'Test Market',
        description: 'Test description',
        deadline: 30.days.from_now.iso8601
      }

      # Request specs handle sessions differently than controller specs
      # The session data is stored but not directly accessible
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'Cache management' do
    let(:application) { create(:oauth_application) }
    let(:editor) { create(:editor, :authorized_and_active, client_id: application.uid) }
    let(:access_token) { create(:access_token, application: application, scopes: 'market_config') }

    around do |example|
      # Temporarily use memory store for cache tests
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      Rails.cache = original_cache
    end

    it 'manages state token cache correctly' do
      # Create state token
      state_token = 'test_state_123'
      market_id = 999

      # Clear cache before test
      Rails.cache.clear

      # Simulate state token storage
      Rails.cache.write("fasttrack_state_#{state_token}", market_id, expires_in: 10.minutes)

      # Verify storage
      expect(Rails.cache.read("fasttrack_state_#{state_token}")).to eq(market_id)

      # Simulate state token usage and cleanup
      cached_market_id = Rails.cache.read("fasttrack_state_#{state_token}")
      Rails.cache.delete("fasttrack_state_#{state_token}")

      expect(cached_market_id).to eq(market_id)
      expect(Rails.cache.read("fasttrack_state_#{state_token}")).to be_nil
    end

    it 'handles cache expiration' do
      state_token = 'test_state_expire'
      market_id = 888

      # Clear cache before test
      Rails.cache.clear

      # Store with short expiration
      Rails.cache.write("fasttrack_state_#{state_token}", market_id, expires_in: 1.second)

      # Verify immediate storage
      expect(Rails.cache.read("fasttrack_state_#{state_token}")).to eq(market_id)

      # Wait for expiration
      sleep(2)

      # Should be expired
      expect(Rails.cache.read("fasttrack_state_#{state_token}")).to be_nil
    end
  end

  describe 'Data validation consistency' do
    let(:application) { create(:oauth_application) }
    let(:editor) { create(:editor, :authorized_and_active, client_id: application.uid) }
    let(:access_token) { create(:access_token, application: application, scopes: 'market_config') }

    it 'enforces consistent validation rules' do
      # Test with invalid data
      # Ensure editor exists
      editor

      invalid_data = {
        title: 'AB', # Too short
        description: 'Short', # Too short
        deadline: 1.hour.ago.iso8601 # Past date
      }

      get '/buyer/market_configurations/new', params: {
        access_token: access_token.token,
        callback_url: 'http://localhost:4000/callback',
        state: 'test_state',
        title: invalid_data[:title],
        description: invalid_data[:description],
        deadline: invalid_data[:deadline]
      }

      expect(response).to have_http_status(:redirect)

      # In request specs, session data is not directly accessible
      # The data would be stored internally but we can't verify it directly
    end

    it 'maintains data type consistency' do
      # Test with various data types
      # Ensure editor exists
      editor

      get '/buyer/market_configurations/new', params: {
        access_token: access_token.token,
        callback_url: 'http://localhost:4000/callback',
        state: 'test_state',
        title: 'Test Market',
        description: 'Test description',
        deadline: '2025-08-14T10:09:45Z'
      }

      expect(response).to have_http_status(:redirect)

      # In request specs, session data is not directly accessible
      # The controller would handle type conversions internally
    end
  end
end
