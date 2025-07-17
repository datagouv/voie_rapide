# frozen_string_literal: true

Rails.application.routes.draw do
  use_doorkeeper

  # Admin routes - Editor management
  namespace :admin do
    resources :editors do
      member do
        patch :sync_doorkeeper
      end
    end
  end

  # Buyer (Editor) routes - OAuth protected market configuration
  namespace :buyer do
    resources :market_configurations, only: %i[new create] do
      collection do
        get :documents
      end

      member do
        get :confirm
      end
    end
  end

  # Candidate routes - Public access for companies
  namespace :candidate do
    get ':fast_track_id', to: 'applications#entry', as: :entry
    get ':fast_track_id/siret', to: 'applications#siret', as: :siret
    post ':fast_track_id/siret', to: 'applications#validate_siret', as: :validate_siret
    get ':fast_track_id/form', to: 'applications#form', as: :form
    patch ':fast_track_id/form', to: 'applications#update', as: :update
    post ':fast_track_id/submit', to: 'applications#submit', as: :submit
    get ':fast_track_id/confirmation', to: 'applications#confirmation', as: :confirmation
    get ':fast_track_id/download', to: 'applications#download_attestation', as: :download_attestation
    get 'error', to: 'applications#error', as: :error
  end

  # API routes - OAuth protected access for editor platforms
  namespace :api do
    namespace :v1 do
      namespace :oauth do
        post 'app_token', to: 'app_authentication#create'
        post 'refresh_token', to: 'app_authentication#refresh'
        get 'app_status', to: 'app_authentication#status'
      end
    end

    namespace :applications do
      get 'download_attestation', to: 'downloads#attestation'
      get 'download_dossier_zip', to: 'downloads#dossier_zip'

      # OPTIONS routes for CORS preflight requests
      options 'download_attestation', to: 'downloads#cors_preflight'
      options 'download_dossier_zip', to: 'downloads#cors_preflight'
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Editor authentication routes
  get 'editor/auth', to: 'editor_auth#new', as: :editor_auth
  post 'editor/auth', to: 'editor_auth#create'
  delete 'editor/auth', to: 'editor_auth#destroy', as: :editor_logout

  # Root path for development
  root 'home#index'
end
