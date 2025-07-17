# frozen_string_literal: true

module Candidate
  class ApplicationSubmissionService
    include Rails.application.routes.url_helpers

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

      # Create ZIP file with all documents
      create_application_zip!
    end

    def generate_attestation!
      pdf_generator = Candidate::AttestationPdfService.new(application)
      attestation_path = pdf_generator.generate!

      application.update!(attestation_path: attestation_path)
    end

    def notify_completion!
      # Log submission for audit trail
      Rails.logger.info "Application submitted: #{application.submission_id} for market #{public_market.fast_track_id}"

      # Future: Send webhook notification to editor platform
      # EditorNotificationService.new(public_market.editor, application).notify!
    end

    def all_required_documents_present?
      required_document_ids = public_market.public_market_configurations
                                           .where(required: true)
                                           .pluck(:document_id)

      attached_document_names = application.documents.map { |doc| extract_document_id_from_filename(doc.filename.to_s) }

      required_document_ids.all? { |id| attached_document_names.include?(id.to_s) }
    end

    def extract_document_id_from_filename(filename)
      # Extract document ID from filename pattern: "document_name_siret.pdf"
      # This assumes documents are named with their ID in the filename
      filename.split('_').first
    end

    def generate_unique_submission_id
      "FT#{Time.current.strftime('%Y%m%d')}#{SecureRandom.hex(4).upcase}"
    end

    def create_application_zip!
      # Future implementation: Create ZIP file with all uploaded documents
      # For now, we'll store the ZIP path for future use
      zip_filename = "candidature_#{application.submission_id}.zip"
      zip_path = Rails.root.join('storage', 'applications', zip_filename)

      # Create directory if it doesn't exist
      FileUtils.mkdir_p(File.dirname(zip_path))

      # Placeholder: In real implementation, we'd create actual ZIP
      # For now, just create empty file to mark the path
      File.write(zip_path, "# Placeholder ZIP file for #{application.submission_id}")

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
