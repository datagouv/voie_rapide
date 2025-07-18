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

    it 'includes DSFR framework' do
      get '/'
      # Check for DSFR CSS classes in the rendered HTML
      expect(response.body).to include('fr-container')
      expect(response.body).to include('fr-grid-row')
      expect(response.body).to include('fr-callout')
      expect(response.body).to include('fr-badge')

      # Check for DSFR theme system
      expect(response.body).to include('data-fr-scheme="system"')

      # Check that DSFR CSS and JS are loaded (without checking exact URLs)
      expect(response.body).to match(/<link[^>]+dsfr[^>]+\.css/)
      expect(response.body).to match(/<script[^>]+dsfr[^>]+\.js/)
    end
  end
end
