# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Candidate Flow', type: :request do
  let(:editor) { create(:editor, :authorized_and_active) }
  let(:public_market) { create(:public_market, editor: editor) }
  let(:document) { create(:document, :obligatoire) }
  let!(:configuration) { create(:public_market_configuration, public_market: public_market, document: document, required: true) }
  let(:valid_siret) { '12345678901234' }

  describe 'Complete candidate flow' do
    it 'allows a candidate to go through the entire application process' do
      # Step 1: Entry page
      get candidate_entry_path(fast_track_id: public_market.fast_track_id)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(public_market.title)
      expect(response.body).to include(document.nom)

      # Step 2: SIRET input page
      get candidate_siret_path(fast_track_id: public_market.fast_track_id)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Identification de votre entreprise')

      # Step 3: SIRET validation
      post candidate_validate_siret_path(fast_track_id: public_market.fast_track_id), params: { siret: valid_siret }
      expect(response).to redirect_to(candidate_form_path(fast_track_id: public_market.fast_track_id))
      follow_redirect!
      expect(response).to have_http_status(:success)

      # Step 4: Form page with auto-created application
      expect(response.body).to include('Formulaire de candidature')
      # Check for formatted SIRET display
      formatted_siret = valid_siret.gsub(/(\d{3})(\d{3})(\d{3})(\d{5})/, '\1 \2 \3 \4')
      expect(response.body).to include(formatted_siret)

      # Verify application was created
      application = public_market.applications.find_by(siret: valid_siret)
      expect(application).to be_present
      expect(application.status).to eq('in_progress')

      # Step 5: Update application data (AJAX)
      patch candidate_update_path(fast_track_id: public_market.fast_track_id), params: {
        application: {
          email: 'test@example.com',
          phone: '0123456789',
          contact_person: 'John Doe'
        }
      }, headers: { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['success']).to be true

      application.reload
      expect(application.email).to eq('test@example.com')
      expect(application.phone).to eq('0123456789')
      expect(application.contact_person).to eq('John Doe')

      # Step 6: Simulate document upload by directly attaching a file
      # In real scenario, this would be done via the form
      application.documents.attach(
        io: StringIO.new('fake pdf content'),
        filename: "#{document.id}_#{application.siret}.pdf",
        content_type: 'application/pdf'
      )

      # Ensure application is ready for submission
      expect(application.reload.ready_for_submission?).to be true

      # Step 7: Submit application
      post candidate_submit_path(fast_track_id: public_market.fast_track_id)
      expect(response).to redirect_to(candidate_confirmation_path(fast_track_id: public_market.fast_track_id))

      application.reload
      expect(application.status).to eq('submitted')
      expect(application.submitted_at).to be_present
      expect(application.submission_id).to be_present
      expect(application.attestation_path).to be_present

      # Step 8: Confirmation page
      follow_redirect!
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Candidature soumise avec succès')
      expect(response.body).to include(application.submission_id)

      # Step 9: Download attestation
      get candidate_download_attestation_path(fast_track_id: public_market.fast_track_id)
      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to eq('application/pdf')
      expect(response.headers['Content-Disposition']).to include('attachment')
    end

    it 'prevents duplicate submissions for the same SIRET' do
      # Create an existing submitted application
      create(:application, :submitted, public_market: public_market, siret: valid_siret)

      # Try to start a new application with the same SIRET
      post candidate_validate_siret_path(fast_track_id: public_market.fast_track_id), params: { siret: valid_siret }
      expect(response).to redirect_to(candidate_error_path(error: 'already_submitted', fast_track_id: public_market.fast_track_id))
    end

    it 'validates SIRET format' do
      post candidate_validate_siret_path(fast_track_id: public_market.fast_track_id), params: { siret: 'invalid' }
      expect(response).to have_http_status(:success)
      expect(response.body).to include('SIRET invalide')
    end

    it 'handles expired markets' do
      public_market.update!(deadline: 1.day.ago)

      get candidate_entry_path(fast_track_id: public_market.fast_track_id)
      expect(response).to redirect_to(candidate_error_path(error: 'market_expired'))
    end

    it 'handles inactive markets' do
      public_market.update!(active: false)

      get candidate_entry_path(fast_track_id: public_market.fast_track_id)
      expect(response).to redirect_to(candidate_error_path(error: 'market_inactive'))
    end

    it 'handles non-existent markets' do
      get candidate_entry_path(fast_track_id: 'INVALID_ID')
      expect(response).to redirect_to(candidate_error_path(error: 'market_not_found'))
    end
  end

  describe 'Session management' do
    it 'maintains session data across steps' do
      # Start with SIRET validation
      post candidate_validate_siret_path(fast_track_id: public_market.fast_track_id), params: { siret: valid_siret }

      # Check that session contains SIRET
      get candidate_form_path(fast_track_id: public_market.fast_track_id)
      expect(response).to have_http_status(:success)
      expect(session[:siret]).to eq(valid_siret)
      expect(session[:fast_track_id]).to eq(public_market.fast_track_id)
    end

    it 'redirects to SIRET input when session is missing' do
      get candidate_form_path(fast_track_id: public_market.fast_track_id)
      expect(response).to redirect_to(candidate_siret_path(fast_track_id: public_market.fast_track_id))
    end
  end

  describe 'Form validation' do
    let!(:application) { create(:application, public_market: public_market, siret: valid_siret) }

    before do
      # Simulate session setup
      post candidate_validate_siret_path(fast_track_id: public_market.fast_track_id), params: { siret: valid_siret }
    end

    it 'prevents submission with incomplete form' do
      # Try to submit without required fields
      post candidate_submit_path(fast_track_id: public_market.fast_track_id)
      expect(response).to redirect_to(candidate_form_path(fast_track_id: public_market.fast_track_id))
      expect(flash[:error]).to include('formulaire n\'est pas complet')
    end

    it 'prevents submission without required documents' do
      # Update application with contact info but no documents
      application.update!(
        email: 'test@example.com',
        phone: '0123456789',
        contact_person: 'John Doe'
      )

      post candidate_submit_path(fast_track_id: public_market.fast_track_id)
      expect(response).to redirect_to(candidate_form_path(fast_track_id: public_market.fast_track_id))
      expect(flash[:error]).to include('formulaire n\'est pas complet')
    end
  end
end
