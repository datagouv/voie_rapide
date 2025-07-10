# Guide d'implémentation du flux candidat Fast Track

Ce guide détaille l'implémentation complète du flux candidat pour les entreprises souhaitant candidater aux marchés publics via Fast Track, incluant l'intégration avec les plateformes d'éditeurs via un flux de redirection.

## Table des matières

1. [Vue d'ensemble du flux candidat](#vue-densemble-du-flux-candidat)
2. [Architecture technique](#architecture-technique)
3. [Intégration avec les plateformes](#intégration-avec-les-plateformes)
4. [Étapes du flux candidat](#étapes-du-flux-candidat)
5. [Implémentation des contrôleurs](#implémentation-des-contrôleurs)
6. [Modèles et validations](#modèles-et-validations)
7. [Services métier](#services-métier)
8. [Vues et interface utilisateur](#vues-et-interface-utilisateur)
9. [Gestion des sessions](#gestion-des-sessions)
10. [Upload et gestion des documents](#upload-et-gestion-des-documents)
11. [Génération des attestations PDF](#génération-des-attestations-pdf)
12. [Gestion des erreurs](#gestion-des-erreurs)
13. [Tests et validation](#tests-et-validation)
14. [Sécurité et conformité](#sécurité-et-conformité)
15. [Déploiement et monitoring](#déploiement-et-monitoring)

## Vue d'ensemble du flux candidat

### Processus métier

Le flux candidat Fast Track permet aux entreprises de candidater simplement aux marchés publics via deux modes d'accès :

#### Mode Direct (Accès public)
1. **Point d'entrée** : L'entreprise accède directement via un lien contenant le Fast Track ID
2. **Identification** : Saisie et validation du SIRET de l'entreprise
3. **Formulaire** : Remplissage des informations et upload des documents requis
4. **Soumission** : Validation finale et soumission de la candidature
5. **Attestation** : Téléchargement de l'attestation de dépôt officielle

#### Mode Plateforme (Intégration éditeur)
1. **Redirection** : La plateforme redirige vers Fast Track avec Fast Track ID + callback URL
2. **Identification** : Saisie et validation du SIRET de l'entreprise
3. **Formulaire** : Remplissage des informations et upload des documents requis
4. **Soumission** : Validation finale et soumission de la candidature
5. **Callback** : Redirection vers la plateforme avec ID de soumission
6. **Confirmation** : La plateforme affiche la confirmation de candidature

### Contraintes techniques

- **Sans authentification** : Accès public via Fast Track ID
- **Session temporaire** : Gestion d'état sans compte utilisateur
- **Documents PDF uniquement** : Validation stricte des formats
- **Soumission unique** : Une seule candidature par SIRET et par marché
- **Attestation obligatoire** : Preuve officielle de dépôt
- **Callback sécurisé** : Validation des URL de callback et paramètres d'état

## Architecture technique

### Structure des contrôleurs

```
app/controllers/candidate/
├── base_controller.rb          # Contrôleur de base avec sécurité
└── applications_controller.rb  # Gestion complète du flux candidat
```

### Modèles impliqués

```
app/models/
├── application.rb              # Candidature d'entreprise
├── public_market.rb           # Marché public configuré
├── document.rb                # Documents requis
└── public_market_configuration.rb # Association marché-documents
```

### Services métier

```
app/services/candidate/
├── application_submission_service.rb  # Soumission atomique
├── attestation_pdf_service.rb        # Génération PDF
└── platform_callback_service.rb      # Gestion des callbacks plateformes
```

## Intégration avec les plateformes

### Flux de redirection plateforme

#### Étapes d'intégration

1. **Initiation** : La plateforme redirige vers Fast Track
2. **Configuration** : L'utilisateur complète sa candidature
3. **Callback** : Fast Track redirige vers la plateforme avec les résultats
4. **Traitement** : La plateforme traite la réponse et met à jour son état

#### URL de redirection

```
GET /candidate/:fast_track_id?callback_url=https://platform.com/callback&state=security_token
```

#### Paramètres requis

- `fast_track_id` : Identifiant unique du marché
- `callback_url` : URL de callback de la plateforme (optionnel)
- `state` : Token de sécurité pour CSRF protection (optionnel)

### Callback de retour

#### Format de callback

```
GET https://platform.com/callback?
  submission_id=FT20250709ABC123&
  siret=12345678901234&
  status=submitted&
  state=security_token
```

#### Paramètres de callback

- `submission_id` : ID unique de la soumission Fast Track
- `siret` : SIRET de l'entreprise candidate
- `status` : Statut de la candidature (submitted, cancelled, error)
- `state` : Token de sécurité (si fourni lors de l'initiation)

### Exemple d'implémentation plateforme

#### Node.js/Express

```javascript
// Route pour initier la candidature
app.post('/markets/:marketId/apply', (req, res) => {
  const { marketId } = req.params;
  const { fastTrackId } = req.body;
  
  // Générer un token de sécurité
  const state = require('crypto').randomBytes(16).toString('hex');
  
  // Stocker l'état en session
  req.session.candidateStates = req.session.candidateStates || {};
  req.session.candidateStates[state] = {
    marketId: marketId,
    initiatedAt: new Date().toISOString()
  };
  
  // Construire l'URL de redirection
  const callbackUrl = `${req.protocol}://${req.get('host')}/candidate-callback`;
  const fastTrackUrl = new URL(`/candidate/${fastTrackId}`, 'https://fasttrack.gouv.fr');
  fastTrackUrl.searchParams.append('callback_url', callbackUrl);
  fastTrackUrl.searchParams.append('state', state);
  
  res.redirect(fastTrackUrl.toString());
});

// Route de callback
app.get('/candidate-callback', (req, res) => {
  const { submission_id, siret, status, state } = req.query;
  
  try {
    // Valider le paramètre state
    if (!state || !req.session.candidateStates || !req.session.candidateStates[state]) {
      throw new Error('Invalid state parameter');
    }
    
    const stateData = req.session.candidateStates[state];
    delete req.session.candidateStates[state];
    
    // Traiter le résultat
    if (status === 'submitted') {
      // Mettre à jour la base de données
      updateMarketApplication(stateData.marketId, {
        submissionId: submission_id,
        siret: siret,
        status: 'submitted',
        submittedAt: new Date()
      });
      
      res.redirect(`/markets/${stateData.marketId}?application=success`);
    } else if (status === 'cancelled') {
      res.redirect(`/markets/${stateData.marketId}?application=cancelled`);
    } else {
      res.redirect(`/markets/${stateData.marketId}?application=error`);
    }
    
  } catch (error) {
    console.error('Candidate callback error:', error.message);
    res.redirect('/error?message=' + encodeURIComponent(error.message));
  }
});
```

#### Rails

```ruby
# app/controllers/candidate_applications_controller.rb
class CandidateApplicationsController < ApplicationController
  def create
    market = Market.find(params[:market_id])
    
    # Générer un token de sécurité
    state = SecureRandom.hex(16)
    session[:candidate_states] ||= {}
    session[:candidate_states][state] = {
      market_id: market.id,
      initiated_at: Time.current.iso8601
    }
    
    # Construire l'URL de redirection
    callback_url = candidate_callback_url
    fast_track_url = "#{ENV['FASTTRACK_BASE_URL']}/candidate/#{market.fast_track_id}"
    
    redirect_params = {
      callback_url: callback_url,
      state: state
    }
    
    redirect_url = "#{fast_track_url}?#{redirect_params.to_query}"
    redirect_to redirect_url, allow_other_host: true
  end
  
  def callback
    submission_id = params[:submission_id]
    siret = params[:siret]
    status = params[:status]
    state = params[:state]
    
    # Valider le paramètre state
    unless state && session[:candidate_states] && session[:candidate_states][state]
      redirect_to root_path, alert: 'Invalid callback state'
      return
    end
    
    state_data = session[:candidate_states][state]
    session[:candidate_states].delete(state)
    
    market = Market.find(state_data[:market_id])
    
    case status
    when 'submitted'
      # Mettre à jour l'application
      market.candidate_applications.create!(
        submission_id: submission_id,
        siret: siret,
        status: 'submitted',
        submitted_at: Time.current
      )
      
      redirect_to market_path(market), notice: 'Candidature soumise avec succès!'
    when 'cancelled'
      redirect_to market_path(market), notice: 'Candidature annulée'
    else
      redirect_to market_path(market), alert: 'Erreur lors de la candidature'
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'Marché non trouvé'
  end
end
```

## Étapes du flux candidat

### 1. Point d'entrée (Entry)

**Route** : `GET /candidate/:fast_track_id`

**Paramètres optionnels** :
- `callback_url` : URL de callback de la plateforme
- `state` : Token de sécurité pour CSRF protection

**Objectifs** :
- Afficher les informations du marché
- Lister les documents requis (obligatoires/optionnels)
- Fournir les informations importantes (format, délais)
- Stocker les paramètres de callback en session

**Contrôleur** :
```ruby
def entry
  # Stocker les paramètres de callback en session
  if params[:callback_url].present?
    session[:platform_callback] = {
      url: params[:callback_url],
      state: params[:state]
    }
  end
  
  @document_requirements = @public_market.public_market_configurations
                                         .includes(:document)
                                         .order('documents.obligatoire DESC, documents.nom ASC')
  
  @has_platform_callback = session[:platform_callback].present?
end
```

### 2. Identification SIRET

**Route** : `GET /candidate/:fast_track_id/siret`

**Objectifs** :
- Saisie du SIRET de l'entreprise (14 chiffres)
- Validation en temps réel côté client
- Prévention des caractères non numériques
- Affichage des informations sur l'intégration plateforme

**Validation côté client** :
```javascript
function validateSiret(siret) {
  const cleanSiret = siret.replace(/\s/g, '');
  return /^\d{14}$/.test(cleanSiret);
}
```

**Validation côté serveur** :
```ruby
def valid_siret_format?(siret)
  return false unless siret
  siret.match?(/\A\d{14}\z/)
end
```

### 3. Validation SIRET

**Route** : `POST /candidate/:fast_track_id/siret`

**Logique métier** :
- Validation du format SIRET
- Vérification des candidatures existantes
- Récupération des informations entreprise (mock en MVP)
- Stockage en session

**Contrôleur** :
```ruby
def validate_siret
  siret = params[:siret]&.gsub(/\s/, '')
  
  if valid_siret_format?(siret)
    handle_valid_siret(siret)
  else
    handle_invalid_siret
  end
end

private

def handle_valid_siret(siret)
  session[:siret] = siret
  
  existing_application = @public_market.applications.find_by(siret: siret)
  
  if existing_application&.submitted?
    redirect_to candidate_error_path(error: 'already_submitted')
  else
    redirect_to candidate_form_path(fast_track_id: @public_market.fast_track_id)
  end
end
```

### 4. Formulaire de candidature

**Route** : `GET /candidate/:fast_track_id/form`

**Fonctionnalités** :
- Affichage des informations entreprise (lecture seule)
- Formulaire de contact (email, téléphone, personne de contact)
- Upload des documents requis
- Sauvegarde automatique (AJAX)
- Indicateur de progression
- Gestion des callbacks plateformes

**Création automatique de l'application** :
```ruby
def find_or_create_application
  @application = current_application
  return if @application

  @application = @public_market.applications.build(
    siret: session[:siret],
    company_name: mock_company_info(session[:siret])[:name],
    status: 'in_progress'
  )
  @application.save!
  session[:application_id] = @application.id
end
```

### 5. Soumission de candidature

**Route** : `POST /candidate/:fast_track_id/submit`

**Validation pré-soumission** :
- Vérification de la complétude du formulaire
- Contrôle de la présence des documents obligatoires
- Validation des délais

**Service de soumission atomique** :
```ruby
def submit
  if @application.ready_for_submission?
    result = Candidate::ApplicationSubmissionService.new(@application).submit!
    
    if result.success?
      handle_successful_submission
    else
      handle_submission_error(result.error)
    end
  else
    flash[:error] = 'Le formulaire n\'est pas complet.'
    redirect_to candidate_form_path(fast_track_id: @public_market.fast_track_id)
  end
end

private

def handle_successful_submission
  session[:application_id] = @application.id
  
  # Vérifier s'il y a un callback plateforme
  if session[:platform_callback].present?
    redirect_to_platform_callback
  else
    redirect_to candidate_confirmation_path(fast_track_id: @public_market.fast_track_id)
  end
end

def redirect_to_platform_callback
  callback_data = session[:platform_callback]
  session.delete(:platform_callback)
  
  callback_url = URI.parse(callback_data[:url])
  callback_params = {
    submission_id: @application.submission_id,
    siret: @application.siret,
    status: 'submitted'
  }
  
  # Ajouter le paramètre state s'il était fourni
  callback_params[:state] = callback_data[:state] if callback_data[:state].present?
  
  callback_url.query = callback_params.to_query
  
  redirect_to callback_url.to_s, allow_other_host: true
end
```

### 6. Page de confirmation

**Route** : `GET /candidate/:fast_track_id/confirmation`

**Contenu** :
- Confirmation de soumission avec ID unique
- Récapitulatif du marché et de la candidature
- Bouton de téléchargement de l'attestation (critique)
- Instructions pour les étapes suivantes
- Gestion des retours depuis les plateformes

### 7. Gestion des annulations

**Route** : `GET /candidate/:fast_track_id/cancel`

**Fonctionnalités** :
- Annulation de la candidature en cours
- Nettoyage des données de session
- Redirection vers la plateforme avec statut 'cancelled'

**Contrôleur** :
```ruby
def cancel
  # Nettoyer les données de session
  session.delete(:siret)
  session.delete(:application_id)
  
  # Vérifier s'il y a un callback plateforme
  if session[:platform_callback].present?
    callback_data = session[:platform_callback]
    session.delete(:platform_callback)
    
    callback_url = URI.parse(callback_data[:url])
    callback_params = {
      status: 'cancelled'
    }
    
    callback_params[:state] = callback_data[:state] if callback_data[:state].present?
    
    callback_url.query = callback_params.to_query
    
    redirect_to callback_url.to_s, allow_other_host: true
  else
    redirect_to candidate_entry_path(fast_track_id: @public_market.fast_track_id), 
                notice: 'Candidature annulée'
  end
end
```

## Implémentation des contrôleurs

### Contrôleur de base

```ruby
# app/controllers/candidate/base_controller.rb
module Candidate
  class BaseController < ApplicationController
    layout 'candidate'

    before_action :find_public_market
    before_action :validate_market_access
    before_action :validate_callback_url

    private

    def find_public_market
      fast_track_id = params[:fast_track_id] || session[:fast_track_id]
      
      if fast_track_id
        @public_market = PublicMarket.find_by(fast_track_id: fast_track_id)
        session[:fast_track_id] = fast_track_id if @public_market
      end

      return if @public_market

      redirect_to candidate_error_path(error: 'market_not_found')
    end

    def validate_market_access
      return unless @public_market

      if @public_market.deadline < Time.current
        redirect_to candidate_error_path(error: 'market_expired')
      elsif !@public_market.active?
        redirect_to candidate_error_path(error: 'market_inactive')
      end
    end

    def validate_callback_url
      return unless params[:callback_url].present?
      
      begin
        callback_uri = URI.parse(params[:callback_url])
        
        # Valider le domaine callback
        unless valid_callback_domain?(callback_uri.host)
          Rails.logger.warn "Invalid callback domain: #{callback_uri.host}"
          redirect_to candidate_error_path(error: 'invalid_callback_url')
          return
        end
        
        # Valider le protocole (HTTPS en production)
        if Rails.env.production? && callback_uri.scheme != 'https'
          Rails.logger.warn "Invalid callback protocol: #{callback_uri.scheme}"
          redirect_to candidate_error_path(error: 'invalid_callback_protocol')
          return
        end
        
      rescue URI::InvalidURIError
        Rails.logger.warn "Invalid callback URL format: #{params[:callback_url]}"
        redirect_to candidate_error_path(error: 'invalid_callback_url')
      end
    end

    def valid_callback_domain?(domain)
      return true if Rails.env.development? && domain.include?('localhost')
      
      # Liste des domaines autorisés en production
      allowed_domains = [
        'platform1.com',
        'platform2.gouv.fr',
        'procurement.fr'
      ]
      
      allowed_domains.any? { |allowed| domain.ends_with?(allowed) }
    end

    def current_application
      return unless @public_market && session[:siret]
      @current_application ||= @public_market.applications.find_by(siret: session[:siret])
    end

    def require_siret
      return if session[:siret]
      redirect_to candidate_siret_path(fast_track_id: @public_market.fast_track_id)
    end
  end
end
```

## Services métier

### Service de callback plateforme

```ruby
# app/services/candidate/platform_callback_service.rb
module Candidate
  class PlatformCallbackService
    attr_reader :application, :callback_data

    def initialize(application, callback_data)
      @application = application
      @callback_data = callback_data
    end

    def build_callback_url(status = 'submitted')
      return nil unless callback_data.present?
      
      callback_url = URI.parse(callback_data[:url])
      
      callback_params = {
        submission_id: application.submission_id,
        siret: application.siret,
        status: status
      }
      
      # Ajouter le paramètre state s'il était fourni
      callback_params[:state] = callback_data[:state] if callback_data[:state].present?
      
      callback_url.query = callback_params.to_query
      callback_url.to_s
    end

    def validate_callback_data
      return true unless callback_data.present?
      
      url = callback_data[:url]
      return false unless url.present?
      
      begin
        uri = URI.parse(url)
        return false unless %w[http https].include?(uri.scheme)
        return false unless uri.host.present?
        
        true
      rescue URI::InvalidURIError
        false
      end
    end

    def log_callback_attempt(status)
      Rails.logger.info "Platform callback attempt: #{status}", {
        application_id: application.id,
        siret: application.siret,
        callback_url: callback_data[:url],
        status: status
      }
    end
  end
end
```

### Service de soumission amélioré

```ruby
# app/services/candidate/application_submission_service.rb
module Candidate
  class ApplicationSubmissionService
    attr_reader :application, :public_market

    def initialize(application)
      @application = application
      @public_market = application.public_market
    end

    def submit!
      ActiveRecord::Base.transaction do
        validate_submission!
        process_submission!
        generate_attestation!
        log_submission_success!
      end

      Result.success(application)
    rescue StandardError => e
      Rails.logger.error "Application submission failed: #{e.message}", {
        application_id: application.id,
        siret: application.siret,
        error: e.message,
        backtrace: e.backtrace.first(5)
      }
      Result.error(e.message)
    end

    private

    def validate_submission!
      raise 'Application already submitted' if application.submitted?
      raise 'Market deadline passed' if public_market.deadline < Time.current
      raise 'Required documents missing' unless all_required_documents_present?
      raise 'Application form incomplete' unless application.form_complete?
    end

    def process_submission!
      application.update!(
        submitted_at: Time.current,
        status: 'submitted',
        submission_id: generate_unique_submission_id
      )

      create_application_zip!
    end

    def generate_unique_submission_id
      "FT#{Time.current.strftime('%Y%m%d')}#{SecureRandom.hex(4).upcase}"
    end

    def generate_attestation!
      pdf_generator = Candidate::AttestationPdfService.new(application)
      attestation_path = pdf_generator.generate!
      application.update!(attestation_path: attestation_path)
    end

    def log_submission_success!
      Rails.logger.info "Application submitted successfully", {
        application_id: application.id,
        submission_id: application.submission_id,
        siret: application.siret,
        market_id: public_market.id,
        fast_track_id: public_market.fast_track_id
      }
    end

    def all_required_documents_present?
      required_document_ids = public_market.public_market_configurations
                                           .where(required: true)
                                           .pluck(:document_id)

      return true if required_document_ids.empty?

      # Vérification que tous les documents requis sont attachés
      attached_document_ids = application.documents.attachments
                                        .joins(:blob)
                                        .where('active_storage_blobs.filename LIKE ?', '%.pdf')
                                        .pluck('SUBSTRING(active_storage_blobs.filename FROM \'^([0-9]+)_\')')
                                        .map(&:to_i)

      (required_document_ids - attached_document_ids).empty?
    end

    def create_application_zip!
      # Créer un ZIP contenant tous les documents
      zip_path = Rails.root.join('storage', 'applications', "#{application.submission_id}.zip")
      FileUtils.mkdir_p(File.dirname(zip_path))

      # Implémentation ZIP à ajouter selon les besoins
      # Zip::File.open(zip_path, Zip::File::CREATE) do |zip|
      #   application.documents.each do |document|
      #     zip.add(document.filename.to_s, document.blob.service.path_for(document.blob.key))
      #   end
      # end

      application.update!(dossier_zip_path: zip_path.to_s)
    end

    class Result
      attr_reader :application, :error

      def initialize(success, application_or_error)
        @success = success
        if success
          @application = application_or_error
        else
          @error = application_or_error
        end
      end

      def success?
        @success
      end

      def self.success(application)
        new(true, application)
      end

      def self.error(error)
        new(false, error)
      end
    end
  end
end
```

## Vues et interface utilisateur

### Layout candidat avec support plateforme

```erb
<!-- app/views/layouts/candidate.html.erb -->
<!DOCTYPE html>
<html lang="fr">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title><%= content_for?(:title) ? yield(:title) : "Fast Track - République Française" %></title>
    
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
    
    <style>
      /* Styles spécifiques au flux candidat */
      .candidate-container {
        max-width: 800px;
        margin: 0 auto;
        padding: 2rem 1rem;
      }
      
      .platform-integration-notice {
        background: #e0f2fe;
        border: 1px solid #0288d1;
        border-radius: 0.5rem;
        padding: 1rem;
        margin-bottom: 2rem;
        color: #01579b;
      }
      
      .platform-integration-notice h3 {
        margin: 0 0 0.5rem 0;
        color: #01579b;
      }
      
      .step-indicator {
        display: flex;
        justify-content: center;
        margin-bottom: 2rem;
        padding: 0;
        list-style: none;
      }
      
      .step-indicator li {
        flex: 1;
        max-width: 200px;
        text-align: center;
        padding: 0.75rem;
        color: #6b7280;
        font-weight: 500;
      }
      
      .step-indicator .active {
        color: #3b82f6;
        font-weight: 700;
      }
      
      .step-indicator .completed {
        color: #059669;
      }
      
      .candidate-card {
        background: white;
        border-radius: 0.75rem;
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        overflow: hidden;
      }
      
      .actions {
        display: flex;
        gap: 1rem;
        justify-content: center;
        margin-top: 2rem;
      }
      
      .btn {
        padding: 0.75rem 1.5rem;
        border: none;
        border-radius: 0.375rem;
        font-weight: 600;
        text-decoration: none;
        cursor: pointer;
        transition: all 0.2s;
      }
      
      .btn-primary {
        background-color: #3b82f6;
        color: white;
      }
      
      .btn-primary:hover {
        background-color: #2563eb;
      }
      
      .btn-secondary {
        background-color: #6b7280;
        color: white;
      }
      
      .btn-secondary:hover {
        background-color: #4b5563;
      }
      
      .btn-outline {
        background-color: transparent;
        color: #3b82f6;
        border: 2px solid #3b82f6;
      }
      
      .btn-outline:hover {
        background-color: #3b82f6;
        color: white;
      }
    </style>
  </head>

  <body>
    <div class="candidate-container">
      <header class="candidate-header">
        <h1>🇫🇷 Fast Track</h1>
        <p class="subtitle">Candidature simplifiée aux marchés publics</p>
      </header>

      <% if session[:platform_callback].present? %>
        <div class="platform-integration-notice">
          <h3>🔗 Intégration Plateforme</h3>
          <p>Vous candidatez via votre plateforme d'achat. Une fois votre candidature terminée, vous serez automatiquement redirigé vers votre plateforme.</p>
        </div>
      <% end %>

      <main>
        <%= yield %>
      </main>

      <footer class="footer">
        <p>République Française - Fast Track</p>
        <% if session[:platform_callback].present? %>
          <div class="actions">
            <%= link_to "Annuler et retourner à la plateforme", 
                candidate_cancel_path(fast_track_id: params[:fast_track_id]), 
                class: "btn btn-outline", 
                method: :get,
                confirm: "Êtes-vous sûr de vouloir annuler cette candidature ?" %>
          </div>
        <% end %>
      </footer>
    </div>
  </body>
</html>
```

### Page d'entrée avec support plateforme

```erb
<!-- app/views/candidate/applications/entry.html.erb -->
<% content_for :title, "Candidature - #{@public_market.titre}" %>

<div class="candidate-card">
  <div class="market-info">
    <h2><%= @public_market.titre %></h2>
    <p><%= @public_market.description %></p>
    
    <div class="market-details">
      <p><strong>Type de marché :</strong> <%= @public_market.type_marche %></p>
      <p><strong>Date limite :</strong> <%= @public_market.deadline.strftime('%d/%m/%Y à %H:%M') %></p>
      <p><strong>Éditeur :</strong> <%= @public_market.editeur.nom %></p>
    </div>
  </div>

  <div class="documents-required">
    <h3>Documents requis</h3>
    
    <% if @document_requirements.any? %>
      <ul class="documents-list">
        <% @document_requirements.each do |config| %>
          <li class="document-item">
            <span class="document-name"><%= config.document.nom %></span>
            <span class="document-status">
              <% if config.required? %>
                <span class="badge badge-required">Obligatoire</span>
              <% else %>
                <span class="badge badge-optional">Optionnel</span>
              <% end %>
            </span>
            <% if config.document.description.present? %>
              <p class="document-description"><%= config.document.description %></p>
            <% end %>
          </li>
        <% end %>
      </ul>
    <% else %>
      <p>Aucun document spécifique requis pour ce marché.</p>
    <% end %>
  </div>

  <div class="actions">
    <%= link_to "Commencer la candidature", 
        candidate_siret_path(fast_track_id: @public_market.fast_track_id), 
        class: "btn btn-primary" %>
  </div>
</div>

<style>
  .market-info {
    padding: 2rem;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .market-details {
    margin-top: 1.5rem;
    padding-top: 1.5rem;
    border-top: 1px solid #f3f4f6;
  }
  
  .market-details p {
    margin-bottom: 0.5rem;
    color: #6b7280;
  }
  
  .documents-required {
    padding: 2rem;
  }
  
  .documents-list {
    list-style: none;
    padding: 0;
  }
  
  .document-item {
    padding: 1rem;
    border: 1px solid #e5e7eb;
    border-radius: 0.5rem;
    margin-bottom: 1rem;
  }
  
  .document-name {
    font-weight: 600;
    color: #1f2937;
  }
  
  .document-status {
    float: right;
  }
  
  .badge {
    padding: 0.25rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.875rem;
    font-weight: 500;
  }
  
  .badge-required {
    background-color: #fef2f2;
    color: #dc2626;
  }
  
  .badge-optional {
    background-color: #f0f9ff;
    color: #0369a1;
  }
  
  .document-description {
    margin-top: 0.5rem;
    color: #6b7280;
    font-size: 0.875rem;
  }
</style>
```

## Gestion des erreurs avec callback

### Actions de gestion des erreurs

```ruby
def error
  @error_type = params[:error]
  @error_message = error_message_for(@error_type)
  @has_platform_callback = session[:platform_callback].present?
end

private

def error_message_for(error_type)
  case error_type
  when 'market_not_found'
    'Le marché demandé n\'existe pas ou l\'ID Fast Track est invalide.'
  when 'market_expired'
    'La date limite de candidature pour ce marché est dépassée.'
  when 'market_inactive'
    'Ce marché n\'est plus disponible pour les candidatures.'
  when 'already_submitted'
    'Une candidature a déjà été soumise avec ce SIRET pour ce marché.'
  when 'invalid_callback_url'
    'L\'URL de callback fournie par la plateforme est invalide.'
  when 'invalid_callback_protocol'
    'Le protocole de callback doit être HTTPS en production.'
  when 'attestation_not_available'
    'L\'attestation n\'est pas disponible ou la candidature n\'a pas été soumise.'
  else
    'Une erreur inattendue s\'est produite.'
  end
end
```

### Page d'erreur avec callback

```erb
<!-- app/views/candidate/applications/error.html.erb -->
<% content_for :title, "Erreur - Fast Track" %>

<div class="candidate-card">
  <div class="error-content">
    <h2>❌ Erreur</h2>
    <p><%= @error_message %></p>
    
    <% if @has_platform_callback %>
      <div class="platform-error-actions">
        <p>Vous pouvez retourner à votre plateforme ou réessayer.</p>
        <div class="actions">
          <%= link_to "Retourner à la plateforme", 
              candidate_cancel_path(fast_track_id: params[:fast_track_id]), 
              class: "btn btn-secondary" %>
          <%= link_to "Réessayer", 
              candidate_entry_path(fast_track_id: params[:fast_track_id]), 
              class: "btn btn-primary" %>
        </div>
      </div>
    <% else %>
      <div class="actions">
        <%= link_to "Retourner à l'accueil", 
            candidate_entry_path(fast_track_id: params[:fast_track_id]), 
            class: "btn btn-primary" %>
      </div>
    <% end %>
  </div>
</div>

<style>
  .error-content {
    padding: 3rem;
    text-align: center;
  }
  
  .error-content h2 {
    color: #dc2626;
    margin-bottom: 1rem;
  }
  
  .error-content p {
    color: #6b7280;
    margin-bottom: 2rem;
  }
  
  .platform-error-actions {
    margin-top: 2rem;
  }
  
  .platform-error-actions p {
    margin-bottom: 1rem;
  }
</style>
```

## Routes avec callback

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Candidate routes
  scope :candidate do
    get ':fast_track_id', to: 'candidate/applications#entry', as: :candidate_entry
    get ':fast_track_id/siret', to: 'candidate/applications#siret', as: :candidate_siret
    post ':fast_track_id/siret', to: 'candidate/applications#validate_siret', as: :candidate_validate_siret
    get ':fast_track_id/form', to: 'candidate/applications#form', as: :candidate_form
    patch ':fast_track_id/form', to: 'candidate/applications#update', as: :candidate_update
    post ':fast_track_id/submit', to: 'candidate/applications#submit', as: :candidate_submit
    get ':fast_track_id/confirmation', to: 'candidate/applications#confirmation', as: :candidate_confirmation
    get ':fast_track_id/download', to: 'candidate/applications#download_attestation', as: :candidate_download
    get ':fast_track_id/cancel', to: 'candidate/applications#cancel', as: :candidate_cancel
    get ':fast_track_id/error', to: 'candidate/applications#error', as: :candidate_error
  end
end
```

## Sécurité et conformité

### Validation des callbacks

```ruby
# app/services/candidate/callback_validator.rb
module Candidate
  class CallbackValidator
    ALLOWED_DOMAINS = [
      'localhost',
      'platform1.com',
      'platform2.gouv.fr',
      'procurement.fr'
    ].freeze

    def self.valid_callback_url?(url)
      return false unless url.present?

      begin
        uri = URI.parse(url)
        
        # Vérifier le protocole
        return false unless %w[http https].include?(uri.scheme)
        
        # HTTPS obligatoire en production
        return false if Rails.env.production? && uri.scheme != 'https'
        
        # Vérifier le domaine
        return false unless valid_domain?(uri.host)
        
        # Vérifier la longueur
        return false if url.length > 2000
        
        true
      rescue URI::InvalidURIError
        false
      end
    end

    def self.valid_domain?(host)
      return false unless host.present?
      
      # Permettre localhost en développement
      return true if Rails.env.development? && host.include?('localhost')
      
      # Vérifier les domaines autorisés
      ALLOWED_DOMAINS.any? { |domain| host.ends_with?(domain) }
    end

    def self.sanitize_callback_params(params)
      sanitized = {}
      
      allowed_params = %w[submission_id siret status state]
      
      allowed_params.each do |param|
        value = params[param]
        next unless value.present?
        
        # Nettoyer et valider
        sanitized[param] = value.to_s.strip[0..255]
      end
      
      sanitized
    end
  end
end
```

### Logging et audit

```ruby
# app/models/candidate_audit_log.rb
class CandidateAuditLog < ApplicationRecord
  validates :action, :siret, :fast_track_id, presence: true
  
  scope :recent, -> { where('created_at > ?', 7.days.ago) }
  scope :by_action, ->(action) { where(action: action) }
  
  def self.log_action(action, params = {})
    create!(
      action: action,
      siret: params[:siret],
      fast_track_id: params[:fast_track_id],
      ip_address: params[:ip_address],
      user_agent: params[:user_agent],
      additional_data: params[:additional_data]&.to_json
    )
  end
end
```

## Tests avec intégration plateforme

### Tests d'intégration

```ruby
# spec/requests/candidate/platform_integration_spec.rb
RSpec.describe 'Candidate Platform Integration', type: :request do
  let(:public_market) { create(:public_market) }
  let(:callback_url) { 'https://platform.com/callback' }
  let(:state) { 'secure_random_state' }

  describe 'Platform callback flow' do
    it 'redirects to platform after successful submission' do
      # Démarrer avec callback URL
      get candidate_entry_path(public_market.fast_track_id, 
                              callback_url: callback_url, 
                              state: state)
      
      expect(response).to have_http_status(:success)
      expect(session[:platform_callback]).to be_present
      
      # Compléter la candidature
      complete_candidate_application(public_market)
      
      # Vérifier la redirection
      expect(response).to redirect_to(/#{callback_url}/)
      
      redirect_url = URI.parse(response.location)
      params = CGI.parse(redirect_url.query)
      
      expect(params['status']).to eq(['submitted'])
      expect(params['state']).to eq([state])
      expect(params['submission_id']).to be_present
    end
    
    it 'handles cancellation with platform callback' do
      # Configurer la session avec callback
      get candidate_entry_path(public_market.fast_track_id, 
                              callback_url: callback_url, 
                              state: state)
      
      # Annuler
      get candidate_cancel_path(public_market.fast_track_id)
      
      expect(response).to redirect_to(/#{callback_url}/)
      
      redirect_url = URI.parse(response.location)
      params = CGI.parse(redirect_url.query)
      
      expect(params['status']).to eq(['cancelled'])
      expect(params['state']).to eq([state])
    end
  end
  
  describe 'Callback URL validation' do
    it 'rejects invalid callback URLs' do
      invalid_url = 'http://malicious-site.com/callback'
      
      get candidate_entry_path(public_market.fast_track_id, 
                              callback_url: invalid_url)
      
      expect(response).to redirect_to(candidate_error_path(error: 'invalid_callback_url'))
    end
    
    it 'requires HTTPS in production' do
      allow(Rails.env).to receive(:production?).and_return(true)
      
      http_url = 'http://platform.com/callback'
      
      get candidate_entry_path(public_market.fast_track_id, 
                              callback_url: http_url)
      
      expect(response).to redirect_to(candidate_error_path(error: 'invalid_callback_protocol'))
    end
  end
  
  private
  
  def complete_candidate_application(market)
    # Valider SIRET
    post candidate_validate_siret_path(market.fast_track_id), 
         params: { siret: '12345678901234' }
    
    # Remplir formulaire
    patch candidate_update_path(market.fast_track_id), 
          params: { 
            application: {
              email: 'test@example.com',
              contact_person: 'John Doe',
              phone: '0123456789'
            }
          }
    
    # Soumettre
    post candidate_submit_path(market.fast_track_id)
  end
end
```

## Conclusion

Cette implémentation du flux candidat avec intégration plateforme offre :

### Avantages clés
- **Flexibilité** : Support à la fois de l'accès direct et de l'intégration plateforme
- **Sécurité** : Validation stricte des callbacks et protection CSRF
- **Simplicité** : Flux de redirection standard sans complexité iframe
- **Audit** : Logging complet pour conformité et débogage
- **Expérience utilisateur** : Interface cohérente avec ou sans plateforme

### Sécurité
- Validation des domaines de callback
- Protection CSRF avec paramètres d'état
- Logging complet des actions
- Validation stricte des entrées

### Intégration
- Support transparent des plateformes
- Callbacks sécurisés avec validation
- Gestion d'erreurs robuste
- Documentation complète pour les développeurs

Cette approche permet une intégration transparente avec les plateformes d'achat tout en maintenant la sécurité et la simplicité du flux candidat.