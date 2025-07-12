# frozen_string_literal: true

module Api
  module Applications
    # OAuth-protected downloads for editor platforms
    class DownloadsController < ApplicationController
      before_action :doorkeeper_authorize!
      before_action :find_application
      before_action :verify_editor_access

      # Download attestation PDF - OAuth protected
      def attestation
        unless @application.attestation_path.present? && File.exist?(@application.attestation_path)
          render json: { error: 'Attestation not available' }, status: :not_found
          return
        end

        Rails.logger.info "Editor #{current_editor.name} downloading attestation for application #{@application.submission_id}"

        send_file @application.attestation_path,
                  filename: "attestation_#{@application.siret}_#{@public_market.fast_track_id}.pdf",
                  type: 'application/pdf',
                  disposition: 'attachment'
      end

      # Download dossier ZIP - OAuth protected
      def dossier_zip
        unless @application.dossier_zip_path.present? && File.exist?(@application.dossier_zip_path)
          render json: { error: 'Dossier ZIP not available' }, status: :not_found
          return
        end

        Rails.logger.info "Editor #{current_editor.name} downloading dossier for application #{@application.submission_id}"

        send_file @application.dossier_zip_path,
                  filename: "dossier_#{@application.siret}_#{@public_market.fast_track_id}.zip",
                  type: 'application/zip',
                  disposition: 'attachment'
      end

      private

      def find_application
        fast_track_id = params[:fast_track_id]
        siret = params[:siret]

        unless fast_track_id.present? && siret.present?
          render json: { error: 'Missing required parameters: fast_track_id and siret' }, status: :bad_request
          return
        end

        @public_market = PublicMarket.find_by(fast_track_id: fast_track_id)
        unless @public_market
          render json: { error: 'Market not found' }, status: :not_found
          return
        end

        @application = @public_market.applications.find_by(siret: siret)
        unless @application
          render json: { error: 'Application not found' }, status: :not_found
          return
        end

        return if @application.submitted?

        render json: { error: 'Application not yet submitted' }, status: :forbidden
        nil
      end

      def verify_editor_access
        # Verify that the authenticated editor owns this market
        return if @public_market.editor == current_editor

        Rails.logger.warn "Editor #{current_editor.name} attempted to access market #{@public_market.fast_track_id} owned by #{@public_market.editor.name}"
        render json: { error: 'Access denied - market not owned by your editor platform' }, status: :forbidden
      end

      def current_editor
        @current_editor ||= find_current_editor
      end

      def find_current_editor
        return nil unless doorkeeper_token

        # Find editor by the application associated with the token
        application = doorkeeper_token.application
        Editor.find_by(client_id: application.uid) if application
      end
    end
  end
end
