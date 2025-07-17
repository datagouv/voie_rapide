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
      expect(response.body).to include('Voie Rapide')
      expect(response.body).to include('La plateforme de candidature simplifiée aux marchés publics')
      expect(response.body).to include('Facilitez vos démarches administratives')
    end

    it 'includes DSFR header and footer' do
      get '/'
      expect(response.body).to include('fr-header')
      expect(response.body).to include('fr-footer')
      expect(response.body).to include('République')
      expect(response.body).to include('Simplifiez vos candidatures aux marchés publics')
    end

    it 'includes DSFR CSS and JavaScript' do
      get '/'
      expect(response.body).to include('https://cdn.jsdelivr.net/npm/@gouvfr/dsfr@latest/dist/dsfr.min.css')
      expect(response.body).to include('dsfr.module.min.js')
      expect(response.body).to include('data-fr-scheme="system"')
    end
  end
end
