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
      application_params = params.expect(
        application: [:company_name, :email, :phone, :contact_person,
                      { document_uploads: {} }]
      )

      if @application.update(application_params)
        # Handle file uploads
        handle_document_uploads if params[:application][:document_uploads]

        render json: { success: true, message: 'Données sauvegardées' }
      else
        render json: {
          success: false,
          errors: @application.errors.full_messages
        }, status: :unprocessable_entity
      end
    end

    # Submit application
    def submit
      if @application.ready_for_submission?
        handle_application_submission
      else
        handle_incomplete_application
      end
    end

    # Confirmation and download page
    def confirmation
      @application = Application.find(session[:application_id])

      return if @application&.submitted?

      redirect_to candidate_form_path(fast_track_id: @public_market.fast_track_id)
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

        document = Document.find(document_id)
        @application.documents.attach(
          io: file,
          filename: "#{document.nom.parameterize}_#{@application.siret}.pdf",
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
        session[:application_id] = @application.id
        redirect_to candidate_confirmation_path(fast_track_id: @public_market.fast_track_id)
      else
        flash[:error] = "Erreur lors de la soumission : #{result.error}"
        redirect_to candidate_form_path(fast_track_id: @public_market.fast_track_id)
      end
    end

    def handle_incomplete_application
      flash[:error] = I18n.t('candidate.applications.incomplete_form')
      redirect_to candidate_form_path(fast_track_id: @public_market.fast_track_id)
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
  end
end
