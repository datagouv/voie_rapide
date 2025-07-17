# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Home', type: :request do
  describe 'GET /' do
    it 'returns http success' do
      get '/'
      expect(response).to have_http_status(:success)
    end

    it 'displays the Fast Track test message' do
      get '/'
      expect(response.body).to include('Voie Rapide - Fast Track')
      expect(response.body).to include('Fast Track test page is working!')
      expect(response.body).to include('foundation for our Fast Track procurement application')
    end
  end
end
