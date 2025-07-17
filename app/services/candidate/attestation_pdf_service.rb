# frozen_string_literal: true

module Candidate
  class AttestationPdfService
    attr_reader :application, :public_market

    def initialize(application)
      @application = application
      @public_market = application.public_market
    end

    def generate!
      # For MVP, we'll create a simple text-based PDF
      # In production, use proper PDF library like Prawn or WickedPDF

      pdf_content = generate_pdf_content
      pdf_filename = "attestation_#{application.submission_id}.pdf"
      pdf_path = Rails.root.join('storage', 'attestations', pdf_filename)

      # Ensure directory exists
      FileUtils.mkdir_p(File.dirname(pdf_path))

      # Write PDF content (placeholder implementation)
      File.write(pdf_path, pdf_content)

      pdf_path.to_s
    end

    private

    def generate_pdf_content
      # Simple text content for MVP
      # In production, this would generate actual PDF using Prawn or similar
      header_section + market_section + candidate_section +
        submission_section + documents_section + legal_section
    end

    def header_section
      <<~HEADER
        ATTESTATION DE DÉPÔT FAST TRACK
        ================================

      HEADER
    end

    def market_section
      <<~MARKET
        Marché: #{public_market.title}
        Fast Track ID: #{public_market.fast_track_id}

      MARKET
    end

    def candidate_section
      <<~CANDIDATE
        CANDIDAT
        --------
        SIRET: #{application.siret}
        Entreprise: #{application.company_name}
        Email: #{application.email}
        Téléphone: #{application.phone}
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

    def documents_section
      <<~DOCUMENTS
        DOCUMENTS FOURNIS
        -----------------
        #{generate_document_list}

      DOCUMENTS
    end

    def legal_section
      <<~LEGAL
        INFORMATIONS LÉGALES
        --------------------
        Cette attestation certifie que la candidature a été déposée via la plateforme#{' '}
        Fast Track dans les délais impartis. Elle fait foi de la réception de votre#{' '}
        candidature par l'administration.

        Horodatage: #{Time.current.iso8601}
        Plateforme: Fast Track - République Française

        Cette attestation est générée automatiquement et constitue un accusé de réception#{' '}
        officiel de votre candidature.
      LEGAL
    end

    def generate_document_list
      required_docs = load_required_documents
      optional_docs = load_optional_documents

      document_list = build_required_documents_list(required_docs)
      document_list += build_optional_documents_list(optional_docs) if optional_docs.any?

      document_list
    end

    def load_required_documents
      public_market.public_market_configurations
                   .includes(:document)
                   .where(required: true)
                   .map(&:document)
    end

    def load_optional_documents
      public_market.public_market_configurations
                   .includes(:document)
                   .where(required: false)
                   .map(&:document)
    end

    def build_required_documents_list(required_docs)
      document_list = "Documents obligatoires:\n"
      required_docs.each do |doc|
        status = document_attached?(doc) ? '✓ Fourni' : '✗ Manquant'
        document_list += "  - #{doc.nom}: #{status}\n"
      end
      document_list
    end

    def build_optional_documents_list(optional_docs)
      document_list = "\nDocuments optionnels:\n"
      optional_docs.each do |doc|
        status = document_attached?(doc) ? '✓ Fourni' : '- Non fourni'
        document_list += "  - #{doc.nom}: #{status}\n"
      end
      document_list
    end

    def document_attached?(document)
      # Check if document is attached to application
      # This is a simplified check - in production, we'd have more sophisticated matching
      application.documents.attached? &&
        application.documents.any? { |attached| attached.filename.to_s.include?(document.id.to_s) }
    end
  end
end
