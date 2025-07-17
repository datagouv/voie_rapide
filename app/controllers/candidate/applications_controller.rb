# frozen_string_literal: true

module Candidate
  class ApplicationsController < BaseController
    before_action :require_siret, except: %i[entry siret validate_siret error]
    before_action :find_or_create_application, only: %i[form update submit confirmation]
    before_action :prevent_submission_after_complete, only: %i[form update]

    # Entry point from editor platform
    def entry
      # Display market information and SIRET entry form
      @document_requirements = @public_market.public_market_configurations
                                             .includes(:document)
                                             .order('documents.obligatoire DESC, documents.nom ASC')
    end

    # SIRET validation page
    def siret
      # Render SIRET input form
    end

    # Validate SIRET and create/find application
    def validate_siret
      siret = params[:siret]&.gsub(/\s/, '') # Remove spaces

      if valid_siret_format?(siret)
        handle_valid_siret(siret)
      else
        handle_invalid_siret
      end
    end

    # Application form page
    def form
      @document_requirements = @public_market.public_market_configurations
                                             .includes(:document)
                                             .order('documents.obligatoire DESC, documents.nom ASC')
      @company_info = mock_company_info(session[:siret])
    end

    # Update application data
    def update
      log_update_debug_info

      document_uploads = extract_document_uploads_from_params
      clean_app_params = build_clean_application_params

      if @application.update(clean_app_params)
        process_document_uploads(document_uploads)
        render json: { success: true, message: I18n.t('candidate.applications.data_saved') }
      else
        render json: {
          success: false,
          errors: @application.errors.full_messages
        }, status: :unprocessable_entity
      end
    end

    # Submit application
    def submit
      Rails.logger.info "Submitting application #{@application.id}"

      if @application.ready_for_submission?
        handle_application_submission
      else
        handle_incomplete_application
      end
    end

    # Confirmation and download page
    def confirmation
      return redirect_to_entry_if_no_application unless session[:application_id]

      @application = Application.find(session[:application_id])
      return if @application&.submitted?

      redirect_to_form_if_not_submitted
    end

    # Download attestation PDF
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

    # Error page
    def error
      @error_type = params[:error]
      @error_message = error_message_for(@error_type)
    end

    helper_method :platform_callback_url

    private

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

    def prevent_submission_after_complete
      return unless current_application&.submitted?

      redirect_to candidate_confirmation_path(fast_track_id: @public_market.fast_track_id)
    end

    def valid_siret_format?(siret)
      return false unless siret

      # Basic format validation: exactly 14 digits
      siret.match?(/\A\d{14}\z/)
    end

    def mock_company_info(siret)
      # Mock company data for MVP (replace with real API later)
      {
        name: "Entreprise #{siret[0..8]}",
        address: '123 Rue de la République, 75001 Paris',
        legal_form: 'SAS',
        activity: 'Services informatiques',
        creation_date: '2020-01-15'
      }
    end

    def handle_document_uploads
      document_uploads = params[:application][:document_uploads]

      document_uploads.each do |document_id, file|
        next if file.blank?

        @application.documents.attach(
          io: file,
          filename: "#{document_id}_#{@application.siret}.pdf",
          content_type: 'application/pdf'
        )
      end
    end

    def handle_valid_siret(siret)
      session[:siret] = siret

      # Check if application already exists
      existing_application = @public_market.applications.find_by(siret: siret)

      if existing_application&.submitted?
        redirect_to candidate_error_path(error: 'already_submitted', fast_track_id: @public_market.fast_track_id)
      else
        redirect_to candidate_form_path(fast_track_id: @public_market.fast_track_id)
      end
    end

    def handle_invalid_siret
      flash.now[:error] = I18n.t('candidate.applications.invalid_siret')
      render :siret
    end

    def handle_application_submission
      result = Candidate::ApplicationSubmissionService.new(@application).submit!

      if result.success?
        handle_successful_submission
      else
        handle_failed_submission(result.error)
      end
    end

    def handle_incomplete_application
      errors = []
      errors << 'Email manquant' if @application.email.blank?
      errors << 'Personne de contact manquante' if @application.contact_person.blank?
      errors << 'Documents obligatoires manquants' unless @application.all_required_documents_attached?

      flash[:error] = "Votre candidature est incomplète : #{errors.join(', ')}"
      redirect_to candidate_form_path(fast_track_id: @public_market.fast_track_id)
    end

    def handle_platform_callback
      callback_params = build_callback_params
      callback_url_with_params = "#{platform_callback_url}?#{callback_params.to_query}"

      Rails.logger.info "Platform callback URL: #{callback_url_with_params}"
      Rails.logger.info "Callback params: #{callback_params}"

      clear_platform_session_data

      # Force a full page redirect to avoid CORS issues
      redirect_to callback_url_with_params, allow_other_host: true
    end

    def build_callback_params
      params = {
        fast_track_id: @public_market.fast_track_id,
        siret: @application.siret,
        status: 'completed',
        company_name: @application.company_name,
        submitted_at: @application.submitted_at.iso8601
      }
      params[:state] = session[:platform_state] if session[:platform_state].present?
      params
    end

    def clear_platform_session_data
      session.delete(:platform_callback_url)
      session.delete(:platform_state)
    end

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

    # Extracted methods for update action complexity reduction

    def log_update_debug_info
      Rails.logger.debug { "Updating application #{@application.id}" }
    end

    def extract_document_uploads_from_params
      app_params = params[:application] || {}
      document_uploads = {}

      app_params.each do |key, value|
        key_str = key.to_s
        document_uploads.merge!(extract_complete_document_upload(key_str, value))
        document_uploads.merge!(extract_malformed_document_upload(key_str, value))
      end

      document_uploads
    end

    def extract_complete_document_upload(key_str, value)
      return {} unless key_str.start_with?('document_uploads[') && key_str.end_with?(']')

      match = key_str.match(/document_uploads\[(\d+)\]/)
      return {} unless match

      { match[1] => value }
    end

    def extract_malformed_document_upload(key_str, value)
      return {} unless key_str.start_with?('document_uploads[') && !key_str.end_with?(']')

      match = key_str.match(/document_uploads\[(\d+)/)
      return {} unless match

      document_id = match[1]
      return {} unless (value.is_a?(Hash) || value.is_a?(ActionController::Parameters)) && value.key?(']')

      { document_id => value[']'] }
    end

    def build_clean_application_params
      app_params = params[:application] || {}
      {
        company_name: app_params[:company_name],
        email: app_params[:email],
        phone: app_params[:phone],
        contact_person: app_params[:contact_person]
      }.compact
    end

    def process_document_uploads(document_uploads)
      return unless document_uploads.any?

      # Store document_uploads in params for handle_document_uploads method
      params[:application] ||= {}
      params[:application][:document_uploads] = document_uploads
      handle_document_uploads
    end

    def redirect_to_entry_if_no_application
      flash[:error] = I18n.t('candidate.applications.no_application_found')
      redirect_to candidate_entry_path(fast_track_id: @public_market.fast_track_id)
    end

    def redirect_to_form_if_not_submitted
      flash[:error] = I18n.t('candidate.applications.not_submitted_properly')
      redirect_to candidate_form_path(fast_track_id: @public_market.fast_track_id)
    end

    def handle_successful_submission
      session[:application_id] = @application.id
      redirect_to candidate_confirmation_path(fast_track_id: @public_market.fast_track_id)
    end

    def handle_failed_submission(error)
      Rails.logger.error "Application submission failed: #{error}"
      flash[:error] = "Erreur lors de la soumission : #{error}"
      redirect_to candidate_form_path(fast_track_id: @public_market.fast_track_id)
    end
  end
end
