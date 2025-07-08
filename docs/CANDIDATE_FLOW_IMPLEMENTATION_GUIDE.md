# Guide d'implémentation du flux candidat Fast Track

Ce guide détaille l'implémentation complète du flux candidat pour les entreprises souhaitant candidater aux marchés publics via Fast Track. Il complète le guide d'implémentation de l'éditeur fictif (`FAKE_EDITOR_IMPLEMENTATION_GUIDE.md`).

## Table des matières

1. [Vue d'ensemble du flux candidat](#vue-densemble-du-flux-candidat)
2. [Architecture technique](#architecture-technique)
3. [Étapes du flux candidat](#étapes-du-flux-candidat)
4. [Implémentation des contrôleurs](#implémentation-des-contrôleurs)
5. [Modèles et validations](#modèles-et-validations)
6. [Services métier](#services-métier)
7. [Vues et interface utilisateur](#vues-et-interface-utilisateur)
8. [Gestion des sessions](#gestion-des-sessions)
9. [Upload et gestion des documents](#upload-et-gestion-des-documents)
10. [Génération des attestations PDF](#génération-des-attestations-pdf)
11. [Gestion des erreurs](#gestion-des-erreurs)
12. [Tests et validation](#tests-et-validation)
13. [Sécurité et conformité](#sécurité-et-conformité)
14. [Déploiement et monitoring](#déploiement-et-monitoring)

## Vue d'ensemble du flux candidat

### Processus métier

Le flux candidat Fast Track permet aux entreprises de candidater simplement aux marchés publics :

1. **Point d'entrée** : L'entreprise accède via un lien fourni par la plateforme d'éditeur
2. **Identification** : Saisie et validation du SIRET de l'entreprise
3. **Formulaire** : Remplissage des informations et upload des documents requis
4. **Soumission** : Validation finale et soumission de la candidature
5. **Attestation** : Téléchargement de l'attestation de dépôt officielle

### Contraintes techniques

- **Sans authentification** : Accès public via Fast Track ID
- **Session temporaire** : Gestion d'état sans compte utilisateur
- **Documents PDF uniquement** : Validation stricte des formats
- **Soumission unique** : Une seule candidature par SIRET et par marché
- **Attestation obligatoire** : Preuve officielle de dépôt

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
└── attestation_pdf_service.rb        # Génération PDF
```

## Étapes du flux candidat

### 1. Point d'entrée (Entry)

**Route** : `GET /candidate/:fast_track_id`

**Objectifs** :
- Afficher les informations du marché
- Lister les documents requis (obligatoires/optionnels)
- Fournir les informations importantes (format, délais)

**Contrôleur** :
```ruby
def entry
  @document_requirements = @public_market.public_market_configurations
                                         .includes(:document)
                                         .order('documents.obligatoire DESC, documents.nom ASC')
end
```

**Validations** :
- Vérification de l'existence du marché
- Contrôle de la date limite
- Vérification du statut actif

### 2. Identification SIRET

**Route** : `GET /candidate/:fast_track_id/siret`

**Objectifs** :
- Saisie du SIRET de l'entreprise (14 chiffres)
- Validation en temps réel côté client
- Prévention des caractères non numériques

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

### 5. Mise à jour du formulaire

**Route** : `PATCH /candidate/:fast_track_id/form`

**Sauvegarde automatique** :
- Requêtes AJAX toutes les secondes après modification
- Validation des données en temps réel
- Gestion des uploads de fichiers
- Retour JSON avec statut de succès

**Contrôleur** :
```ruby
def update
  application_params = params.require(:application).permit(
    :company_name, :email, :phone, :contact_person,
    document_uploads: {}
  )

  if @application.update(application_params)
    handle_document_uploads if params[:application][:document_uploads]
    render json: { success: true, message: 'Données sauvegardées' }
  else
    render json: {
      success: false,
      errors: @application.errors.full_messages
    }, status: :unprocessable_entity
  end
end
```

### 6. Soumission de candidature

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
      session[:application_id] = @application.id
      redirect_to candidate_confirmation_path(fast_track_id: @public_market.fast_track_id)
    else
      flash[:error] = "Erreur lors de la soumission : #{result.error}"
      redirect_to candidate_form_path(fast_track_id: @public_market.fast_track_id)
    end
  else
    flash[:error] = 'Le formulaire n\'est pas complet.'
    redirect_to candidate_form_path(fast_track_id: @public_market.fast_track_id)
  end
end
```

### 7. Page de confirmation

**Route** : `GET /candidate/:fast_track_id/confirmation`

**Contenu** :
- Confirmation de soumission avec ID unique
- Récapitulatif du marché et de la candidature
- Bouton de téléchargement de l'attestation (critique)
- Instructions pour les étapes suivantes

### 8. Téléchargement d'attestation

**Route** : `GET /candidate/:fast_track_id/download`

**Sécurité** :
- Vérification de l'existence de l'application
- Contrôle du statut soumis
- Validation de la session

**Contrôleur** :
```ruby
def download_attestation
  @application = Application.find(session[:application_id])

  if @application&.submitted? && @application.attestation_path
    send_file @application.attestation_path,
              filename: "attestation_#{@application.siret}_#{@public_market.fast_track_id}.pdf",
              type: 'application/pdf',
              disposition: 'attachment'
  else
    redirect_to candidate_error_path(error: 'attestation_not_available')
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

### Actions de gestion des erreurs

```ruby
def error
  @error_type = params[:error]
  @error_message = error_message_for(@error_type)
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
  when 'attestation_not_available'
    'L\'attestation n\'est pas disponible ou la candidature n\'a pas été soumise.'
  else
    'Une erreur inattendue s\'est produite.'
  end
end
```

## Modèles et validations

### Modèle Application

```ruby
# app/models/application.rb
class Application < ApplicationRecord
  belongs_to :public_market
  has_many_attached :documents

  validates :siret, presence: true, format: { with: /\A\d{14}\z/, message: 'must contain exactly 14 digits' }
  validates :company_name, presence: true
  validates :public_market_id, uniqueness: { scope: :siret, message: 'An application already exists for this SIRET on this market' }
  validates :status, inclusion: { in: %w[in_progress submitted] }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, if: :submitted?
  validates :contact_person, presence: true, if: :submitted?

  scope :submitted, -> { where(status: 'submitted') }
  scope :in_progress, -> { where(status: 'in_progress') }

  def submitted?
    status == 'submitted'
  end

  def ready_for_submission?
    form_complete? && in_progress?
  end

  def form_complete?
    return false unless email.present? && contact_person.present?
    all_required_documents_attached?
  end

  def all_required_documents_attached?
    required_document_ids = public_market.public_market_configurations
                                         .where(required: true)
                                         .pluck(:document_id)

    return true if required_document_ids.empty?

    # Vérification simplifiée pour MVP
    documents.attached? && required_document_ids.count <= documents.count
  end

  def formatted_siret
    return unless siret.present?
    siret.gsub(/(\d{3})(\d{3})(\d{3})(\d{5})/, '\1 \2 \3 \4')
  end
end
```

## Services métier

### Service de soumission

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
        notify_completion!
      end

      Result.success(application)
    rescue StandardError => e
      Rails.logger.error "Application submission failed: #{e.message}"
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

### Service de génération PDF

```ruby
# app/services/candidate/attestation_pdf_service.rb
module Candidate
  class AttestationPdfService
    attr_reader :application, :public_market

    def initialize(application)
      @application = application
      @public_market = application.public_market
    end

    def generate!
      pdf_content = generate_pdf_content
      pdf_filename = "attestation_#{application.submission_id}.pdf"
      pdf_path = Rails.root.join('storage', 'attestations', pdf_filename)

      FileUtils.mkdir_p(File.dirname(pdf_path))
      File.write(pdf_path, pdf_content)

      pdf_path.to_s
    end

    private

    def generate_pdf_content
      # Contenu textuel pour MVP - remplacer par Prawn en production
      header_section + market_section + candidate_section +
        submission_section + documents_section + legal_section
    end

    def header_section
      <<~HEADER
        ATTESTATION DE DÉPÔT FAST TRACK
        ================================

      HEADER
    end

    def candidate_section
      <<~CANDIDATE
        CANDIDAT
        --------
        SIRET: #{application.siret}
        Entreprise: #{application.company_name}
        Email: #{application.email}
        Contact: #{application.contact_person}

      CANDIDATE
    end

    def submission_section
      <<~SUBMISSION
        SOUMISSION
        ----------
        ID de soumission: #{application.submission_id}
        Date de soumission: #{application.submitted_at.strftime('%d/%m/%Y à %H:%M:%S')}
        Délai limite: #{public_market.deadline.strftime('%d/%m/%Y à %H:%M:%S')}

      SUBMISSION
    end
  end
end
```

## Vues et interface utilisateur

### Layout candidat

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
    </style>
  </head>

  <body>
    <div class="candidate-container">
      <header class="candidate-header">
        <h1>🇫🇷 Fast Track</h1>
        <p class="subtitle">Candidature simplifiée aux marchés publics</p>
      </header>

      <main>
        <%= yield %>
      </main>

      <footer class="footer">
        <p>République Française - Fast Track</p>
      </footer>
    </div>
  </body>
</html>
```

### Formulaire de candidature avec JavaScript

```erb
<!-- app/views/candidate/applications/form.html.erb -->
<%= form_with model: @application, url: candidate_update_path(fast_track_id: @public_market.fast_track_id), 
    method: :patch, local: false, html: { id: 'candidate-form', multipart: true } do |form| %>
  
  <div class="form-group">
    <%= form.label :email, "Adresse e-mail *", class: "form-label" %>
    <%= form.email_field :email, 
        class: "form-control", 
        required: true,
        data: { autosave: true } %>
  </div>

  <!-- Upload de documents -->
  <% @document_requirements.select(&:required?).each do |config| %>
    <div class="document-upload-item">
      <strong><%= config.document.nom %></strong>
      <%= form.file_field "document_uploads[#{config.document.id}]", 
          class: "form-control",
          accept: ".pdf",
          data: { 
            document_id: config.document.id,
            required: true
          } %>
    </div>
  <% end %>

<% end %>

<script>
document.addEventListener('DOMContentLoaded', function() {
  const form = document.getElementById('candidate-form');
  
  // Sauvegarde automatique
  function autoSave() {
    const formData = new FormData(form);
    
    fetch(form.action, {
      method: 'PATCH',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        showSaveStatus();
      }
    });
  }

  // Sauvegarde après modification
  document.querySelectorAll('[data-autosave="true"]').forEach(input => {
    let timeout;
    input.addEventListener('input', function() {
      clearTimeout(timeout);
      timeout = setTimeout(autoSave, 1000);
    });
  });

  // Validation des fichiers PDF
  document.querySelectorAll('input[type="file"]').forEach(input => {
    input.addEventListener('change', function() {
      const file = this.files[0];
      if (file && file.type !== 'application/pdf') {
        alert('Seuls les fichiers PDF sont acceptés');
        this.value = '';
      }
    });
  });
});
</script>
```

## Gestion des sessions

### Configuration sécurisée

```ruby
# config/application.rb
config.session_store :cookie_store, 
  key: '_voie_rapide_session',
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax,
  expire_after: 4.hours
```

### Gestion d'état candidat

```ruby
# Dans BaseController
def clear_candidate_session
  session.delete(:siret)
  session.delete(:application_id)
  session.delete(:fast_track_id)
end

def ensure_session_consistency
  # Vérifier la cohérence entre session et application
  if session[:application_id] && session[:siret]
    application = Application.find_by(id: session[:application_id])
    if !application || application.siret != session[:siret]
      clear_candidate_session
      redirect_to candidate_siret_path(fast_track_id: @public_market.fast_track_id)
    end
  end
end
```

## Upload et gestion des documents

### Configuration Active Storage

```ruby
# config/storage.yml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

# Dans application.rb
config.active_storage.variant_processor = :mini_magick
config.active_storage.max_file_size = 10.megabytes
```

### Validation des documents

```ruby
# Dans ApplicationsController
def handle_document_uploads
  document_uploads = params[:application][:document_uploads]

  document_uploads.each do |document_id, file|
    next unless file.present?

    # Validation du type MIME
    unless file.content_type == 'application/pdf'
      flash[:error] = "Le fichier #{file.original_filename} n'est pas un PDF valide"
      return
    end

    # Validation de la taille
    if file.size > 10.megabytes
      flash[:error] = "Le fichier #{file.original_filename} est trop volumineux (max 10 MB)"
      return
    end

    document = Document.find(document_id)
    @application.documents.attach(
      io: file,
      filename: "#{document.id}_#{@application.siret}.pdf",
      content_type: 'application/pdf'
    )
  end
end
```

### Nettoyage des fichiers temporaires

```ruby
# config/schedule.rb (avec gem whenever)
every 1.day, at: '2:00 am' do
  runner "CleanupTempFilesJob.perform_later"
end

# app/jobs/cleanup_temp_files_job.rb
class CleanupTempFilesJob < ApplicationJob
  def perform
    # Supprimer les applications non soumises de plus de 24h
    Application.where(status: 'in_progress')
               .where('created_at < ?', 24.hours.ago)
               .find_each do |app|
      app.documents.purge
      app.destroy
    end
  end
end
```

## Génération des attestations PDF

### Implémentation avec Prawn (recommandée pour production)

```ruby
# Gemfile
gem 'prawn'
gem 'prawn-table'

# Service PDF amélioré
module Candidate
  class AttestationPdfService
    def generate!
      pdf_path = Rails.root.join('storage', 'attestations', pdf_filename)
      FileUtils.mkdir_p(File.dirname(pdf_path))

      Prawn::Document.generate(pdf_path) do |pdf|
        generate_header(pdf)
        generate_market_info(pdf)
        generate_candidate_info(pdf)
        generate_submission_info(pdf)
        generate_documents_table(pdf)
        generate_legal_footer(pdf)
      end

      pdf_path.to_s
    end

    private

    def generate_header(pdf)
      pdf.image "#{Rails.root}/app/assets/images/marianne.png", width: 60, height: 60
      pdf.move_down 20
      
      pdf.font_size 18
      pdf.text "ATTESTATION DE DÉPÔT", align: :center, style: :bold
      pdf.text "FAST TRACK - RÉPUBLIQUE FRANÇAISE", align: :center
      pdf.move_down 30
    end

    def generate_candidate_info(pdf)
      pdf.font_size 12
      
      data = [
        ["SIRET", application.siret],
        ["Entreprise", application.company_name],
        ["Email", application.email],
        ["Contact", application.contact_person],
        ["Téléphone", application.phone]
      ]
      
      pdf.table(data, width: pdf.bounds.width) do
        row(0).font_style = :bold
        cells.border_width = 1
        cells.padding = 8
      end
    end

    def generate_documents_table(pdf)
      headers = ["Document", "Statut", "Obligatoire"]
      rows = [headers]
      
      required_docs = public_market.public_market_configurations
                                   .includes(:document)
                                   .order('required DESC, documents.nom ASC')
      
      required_docs.each do |config|
        status = document_attached?(config.document) ? "✓ Fourni" : "✗ Manquant"
        required = config.required? ? "Oui" : "Non"
        rows << [config.document.nom, status, required]
      end
      
      pdf.table(rows, header: true, width: pdf.bounds.width)
    end
  end
end
```

### Configuration pour différents environnements

```ruby
# config/environments/production.rb
config.active_storage.service = :amazon

# config/storage.yml
amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: eu-west-1
  bucket: fast-track-attestations-prod
```

## Gestion des erreurs

### Hiérarchie d'erreurs personnalisées

```ruby
# app/errors/candidate_errors.rb
module CandidateErrors
  class BaseError < StandardError; end
  class MarketNotFound < BaseError; end
  class MarketExpired < BaseError; end
  class MarketInactive < BaseError; end
  class ApplicationAlreadySubmitted < BaseError; end
  class InvalidSiret < BaseError; end
  class DocumentValidationError < BaseError; end
end
```

### Gestionnaire d'erreurs global

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  rescue_from CandidateErrors::MarketNotFound, with: :handle_market_not_found
  rescue_from CandidateErrors::MarketExpired, with: :handle_market_expired
  rescue_from CandidateErrors::ApplicationAlreadySubmitted, with: :handle_already_submitted

  private

  def handle_market_not_found
    redirect_to candidate_error_path(error: 'market_not_found')
  end

  def handle_market_expired
    redirect_to candidate_error_path(error: 'market_expired')
  end

  def handle_already_submitted
    redirect_to candidate_error_path(error: 'already_submitted')
  end
end
```

### Logging et monitoring

```ruby
# config/environments/production.rb
config.log_level = :info

# Dans les services
class ApplicationSubmissionService
  def submit!
    Rails.logger.info "Starting application submission for SIRET: #{application.siret}"
    
    # ... logique de soumission
    
    Rails.logger.info "Application submitted successfully: #{application.submission_id}"
  rescue StandardError => e
    Rails.logger.error "Application submission failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
```

## Tests et validation

### Tests d'intégration complets

```ruby
# spec/requests/candidate/candidate_flow_spec.rb
RSpec.describe 'Candidate Flow', type: :request do
  let(:editor) { create(:editor, :authorized_and_active) }
  let(:public_market) { create(:public_market, editor: editor) }
  let(:document) { create(:document, :obligatoire) }
  let!(:configuration) { create(:public_market_configuration, public_market: public_market, document: document) }

  describe 'Complete candidate flow' do
    it 'allows a candidate to go through the entire application process' do
      # Test du flux complet
      get candidate_entry_path(fast_track_id: public_market.fast_track_id)
      expect(response).to have_http_status(:success)

      post candidate_validate_siret_path(fast_track_id: public_market.fast_track_id), 
           params: { siret: '12345678901234' }
      expect(response).to redirect_to(candidate_form_path(fast_track_id: public_market.fast_track_id))

      # ... autres étapes du test
    end
  end

  describe 'Error handling' do
    it 'handles expired markets' do
      public_market.update!(deadline: 1.day.ago)
      get candidate_entry_path(fast_track_id: public_market.fast_track_id)
      expect(response).to redirect_to(candidate_error_path(error: 'market_expired'))
    end
  end
end
```

### Tests unitaires des services

```ruby
# spec/services/candidate/application_submission_service_spec.rb
RSpec.describe Candidate::ApplicationSubmissionService do
  let(:application) { create(:application, :with_required_documents) }
  let(:service) { described_class.new(application) }

  describe '#submit!' do
    context 'when application is valid' do
      it 'submits successfully' do
        result = service.submit!
        
        expect(result.success?).to be true
        expect(application.reload.status).to eq('submitted')
        expect(application.submission_id).to be_present
        expect(application.attestation_path).to be_present
      end
    end

    context 'when market deadline is passed' do
      before { application.public_market.update!(deadline: 1.day.ago) }

      it 'fails with appropriate error' do
        result = service.submit!
        expect(result.success?).to be false
        expect(result.error).to include('deadline passed')
      end
    end
  end
end
```

### Tests JavaScript avec Capybara

```ruby
# spec/system/candidate_application_spec.rb
RSpec.describe 'Candidate Application', type: :system, js: true do
  let(:public_market) { create(:public_market, :with_documents) }

  it 'provides real-time form validation' do
    visit candidate_siret_path(fast_track_id: public_market.fast_track_id)
    
    fill_in 'SIRET', with: '1234567890123'
    expect(find('#submit-siret')).to be_disabled
    
    fill_in 'SIRET', with: '12345678901234'
    expect(find('#submit-siret')).not_to be_disabled
  end

  it 'auto-saves form data' do
    # Navigation jusqu'au formulaire
    visit candidate_form_path(fast_track_id: public_market.fast_track_id)
    
    fill_in 'Email', with: 'test@example.com'
    
    # Attendre la sauvegarde automatique
    expect(page).to have_content('Données sauvegardées')
  end
end
```

## Sécurité et conformité

### Protection CSRF

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  
  # Pour les requêtes AJAX
  before_action :set_csrf_token_header

  private

  def set_csrf_token_header
    response.headers['X-CSRF-Token'] = form_authenticity_token
  end
end
```

### Validation des entrées

```ruby
# Strong parameters stricts
def application_params
  params.require(:application).permit(
    :email, :phone, :contact_person,
    document_uploads: {}
  ).tap do |permitted|
    # Validation supplémentaire
    if permitted[:email] && !permitted[:email].match?(URI::MailTo::EMAIL_REGEXP)
      raise ActionController::ParameterMissing, 'Invalid email format'
    end
  end
end
```

### Limitation du taux de requêtes

```ruby
# Gemfile
gem 'rack-attack'

# config/initializers/rack_attack.rb
Rack::Attack.throttle('candidate_submissions', limit: 3, period: 1.hour) do |req|
  if req.path.include?('/candidate/') && req.post?
    req.ip
  end
end

Rack::Attack.throttle('candidate_form_updates', limit: 30, period: 5.minutes) do |req|
  if req.path.include?('/form') && req.patch?
    req.ip
  end
end
```

### Audit et traçabilité

```ruby
# app/models/application.rb
class Application < ApplicationRecord
  after_create :log_creation
  after_update :log_updates, if: :saved_change_to_status?

  private

  def log_creation
    Rails.logger.info "Application created: SIRET=#{siret}, Market=#{public_market.fast_track_id}"
  end

  def log_updates
    if status == 'submitted'
      Rails.logger.info "Application submitted: ID=#{submission_id}, SIRET=#{siret}"
    end
  end
end
```

## Déploiement et monitoring

### Configuration Docker

```dockerfile
# Dockerfile
FROM ruby:3.2.0-alpine

# Dépendances système pour génération PDF
RUN apk add --no-cache \
  build-base \
  postgresql-dev \
  imagemagick \
  imagemagick-dev

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install --deployment --without development test

COPY . .

# Compilation des assets
RUN RAILS_ENV=production bundle exec rake assets:precompile

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

### Monitoring avec Prometheus

```ruby
# Gemfile
gem 'prometheus_exporter'

# config/initializers/prometheus.rb
unless Rails.env.test?
  require 'prometheus_exporter/middleware'
  
  # Métriques personnalisées
  PrometheusExporter::Server::TypeCollector.new.tap do |collector|
    collector.observe(
      'candidate_applications_total',
      'Total candidate applications',
      type: 'counter'
    )
  end
end
```

### Configuration nginx

```nginx
# /etc/nginx/sites-available/fast-track
upstream fast_track {
  server 127.0.0.1:3000;
}

server {
  listen 80;
  server_name fast-track.gouv.fr;
  
  # Redirection HTTPS obligatoire
  return 301 https://$server_name$request_uri;
}

server {
  listen 443 ssl http2;
  server_name fast-track.gouv.fr;
  
  ssl_certificate /etc/ssl/certs/fast-track.crt;
  ssl_certificate_key /etc/ssl/private/fast-track.key;
  
  # Sécurité
  add_header X-Frame-Options SAMEORIGIN;
  add_header X-Content-Type-Options nosniff;
  add_header X-XSS-Protection "1; mode=block";
  
  # Upload de fichiers
  client_max_body_size 10M;
  
  location / {
    proxy_pass http://fast_track;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
  
  # Cache des assets
  location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    proxy_pass http://fast_track;
  }
}
```

### Sauvegarde et récupération

```bash
#!/bin/bash
# scripts/backup.sh

# Sauvegarde base de données
pg_dump fast_track_production > /backups/db_$(date +%Y%m%d_%H%M%S).sql

# Sauvegarde des fichiers uploadés
tar -czf /backups/storage_$(date +%Y%m%d_%H%M%S).tar.gz storage/

# Nettoyage des anciennes sauvegardes (garde 30 jours)
find /backups -name "*.sql" -mtime +30 -delete
find /backups -name "*.tar.gz" -mtime +30 -delete
```

## Performance et optimisation

### Mise en cache

```ruby
# app/controllers/candidate/applications_controller.rb
def entry
  @document_requirements = Rails.cache.fetch(
    "market_documents_#{@public_market.id}_#{@public_market.updated_at.to_i}",
    expires_in: 1.hour
  ) do
    @public_market.public_market_configurations
                  .includes(:document)
                  .order('documents.obligatoire DESC, documents.nom ASC')
  end
end
```

### Optimisation des requêtes

```ruby
# Éviter N+1
def index
  @applications = @public_market.applications
                                .includes(:documents)
                                .joins(:public_market)
                                .order(created_at: :desc)
end
```

### Compression et CDN

```ruby
# config/environments/production.rb
config.asset_host = 'https://cdn.fast-track.gouv.fr'
config.assets.compress = true
config.assets.js_compressor = :terser
config.assets.css_compressor = :sass
```

## Conclusion

Ce guide présente une implémentation complète et robuste du flux candidat Fast Track, couvrant tous les aspects techniques, sécuritaires et de conformité nécessaires pour un déploiement en production dans l'administration française.

### Points clés à retenir

1. **Sécurité d'abord** : Validation stricte, protection CSRF, limitation des taux
2. **Expérience utilisateur** : Interface intuitive, sauvegarde automatique, gestion d'erreurs
3. **Conformité** : Respect des standards gouvernementaux, audit, traçabilité
4. **Performance** : Mise en cache, optimisation des requêtes, monitoring
5. **Maintenabilité** : Tests complets, documentation, déploiement automatisé

L'implémentation respecte les contraintes techniques françaises et fournit une base solide pour l'évolution future du système.