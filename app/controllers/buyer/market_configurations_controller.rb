# frozen_string_literal: true

module Buyer
  # Controller for market configuration flow
  # Handles the two-step process: market type selection and document configuration
  class MarketConfigurationsController < BaseController
    before_action :configure_iframe_response
    before_action :set_market_configuration, only: %i[documents create confirm]
    before_action :validate_market_type, only: %i[create]
    before_action :store_callback_params, only: %i[new]

    # Step 1: Market type selection
    def new
      log_new_action_debug

      if params[:access_token].present?
        handle_access_token_redirect
        return
      end

      @market_configuration = MarketConfigurationSession.new
      @market_types = available_market_types

      log_buyer_action('market_configuration_started')

      render :market_type_selection
    end

    # Process market type selection and show documents
    def documents
      log_documents_action
      @market_configuration.market_type = extract_market_type

      return handle_invalid_market_type unless @market_configuration.valid_market_type?

      persist_market_type_and_render
    rescue ActionController::ParameterMissing => e
      handle_parameter_missing_error(e)
    end

    # Create final market configuration
    def create
      @market_configuration.attributes = clean_market_configuration_params

      if @market_configuration.valid?
        handle_valid_configuration
      else
        handle_invalid_configuration
      end
    end

    # Confirmation page with Fast Track ID
    def confirm
      @public_market = PublicMarket.find_by!(fast_track_id: params[:id])
      @document_requirements = @public_market.documents.includes(:public_market_configurations)

      log_confirmation_debug_info
      log_buyer_action('market_configuration_confirmed', fast_track_id: @public_market.fast_track_id)
      render :confirmation
    end

    private

    def set_market_configuration
      Rails.logger.info '=== SET_MARKET_CONFIGURATION ==='
      Rails.logger.info "Action name: #{action_name}"
      Rails.logger.info "Session data: #{session[:market_configuration].inspect}"
      @market_configuration = MarketConfigurationSession.new(session[:market_configuration] || {})
      Rails.logger.info "Market config initialized: #{@market_configuration.inspect}"
    end

    def market_configuration_params
      params.expect(market_configuration: [:title, :description, :deadline, :market_type, { optional_document_ids: [] }])
    end

    def clean_market_configuration_params
      cleaned_params = market_configuration_params

      # Remove empty strings from optional_document_ids array
      cleaned_params[:optional_document_ids] = cleaned_params[:optional_document_ids].compact_blank if cleaned_params[:optional_document_ids].present?

      cleaned_params
    end

    def validate_market_type
      return if @market_configuration.market_type.present?

      redirect_to new_buyer_market_configuration_path, alert: I18n.t('buyer.market_configurations.select_market_type')
    end

    def extract_market_type
      log_extraction_details

      market_type_from_params
    end

    def log_extraction_details
      Rails.logger.info '=== EXTRACT_MARKET_TYPE ==='
      Rails.logger.info "Params keys: #{params.keys}"
      Rails.logger.info "Market configuration param: #{params[:market_configuration].inspect}"
    end

    def market_type_from_params
      if params[:market_configuration].present?
        params[:market_configuration][:market_type]
      else
        params[:market_type]
      end
    end

    def log_documents_action
      log_buyer_action('market_configuration_documents_step')
    end

    def handle_invalid_market_type
      flash.now[:alert] = I18n.t('buyer.market_configurations.select_market_type')
      @market_types = available_market_types
      render :market_type_selection, status: :unprocessable_entity
    end

    def persist_market_type_and_render
      persist_market_configuration
      load_documents_for_market_type
      log_buyer_action('market_configuration_documents_loaded', market_type: @market_configuration.market_type)
      render :document_selection
    end

    def handle_parameter_missing_error(error)
      Rails.logger.error "Parameter missing in documents action: #{error.message}"
      flash.now[:alert] = I18n.t('buyer.market_configurations.select_market_type')
      @market_types = available_market_types
      render :market_type_selection, status: :unprocessable_entity
    end

    def load_documents_for_market_type
      @mandatory_documents = Document.mandatory_for_market_type(@market_configuration.market_type)
      @optional_documents = Document.optional_for_market_type(@market_configuration.market_type)
    end

    def available_market_types
      [
        ['Fournitures (Goods/Supplies)', 'supplies'],
        ['Services', 'services'],
        ['Travaux (Construction/Works)', 'works']
      ]
    end

    def handle_valid_configuration
      result = MarketConfigurationService.new(current_editor, @market_configuration).create!

      if result.success?
        log_buyer_action('market_configuration_created', fast_track_id: result.fast_track_id)
        redirect_to confirm_buyer_market_configuration_path(result.fast_track_id)
      else
        flash.now[:alert] = I18n.t('buyer.market_configurations.creation_failed')
        load_document_lists
        render :document_selection, status: :unprocessable_entity
      end
    end

    def handle_invalid_configuration
      load_document_lists
      flash.now[:alert] = I18n.t('buyer.market_configurations.correct_errors')
      render :document_selection, status: :unprocessable_entity
    end

    def load_document_lists
      @mandatory_documents = Document.mandatory_for_market_type(@market_configuration.market_type)
      @optional_documents = Document.optional_for_market_type(@market_configuration.market_type)
    end

    # Store configuration in session for multi-step flow
    def persist_market_configuration
      session[:market_configuration] = @market_configuration.to_h
    end

    # Store callback parameters for redirect flow
    def store_callback_params
      log_store_callback_params_debug

      return if params[:callback_url].blank?

      session[:platform_callback] = {
        url: params[:callback_url],
        state: params[:state]
      }
      log_callback_storage
    end

    def log_callback_storage
      Rails.logger.info '=== CALLBACK STORAGE ==='
      log_callback_details
    end

    def log_callback_details
      Rails.logger.info "Stored platform callback URL: #{params[:callback_url]}"
      Rails.logger.info "Stored platform callback state: #{params[:state]}"
      Rails.logger.info "Full platform callback data: #{session[:platform_callback].inspect}"
      Rails.logger.info "Session ID: #{session.id}"
    end

    def log_confirmation_debug_info
      Rails.logger.info '=== CONFIRMATION PAGE ==='
      log_confirmation_session_data
    end

    # Handle platform callback redirect
    def handle_platform_callback
      callback_data = session[:platform_callback]
      session.delete(:platform_callback)

      if valid_callback_data?(callback_data)
        perform_callback_redirect(callback_data)
      else
        handle_missing_callback
      end
    end

    def valid_callback_data?(callback_data)
      callback_data.present? && callback_data['url'].present?
    end

    def perform_callback_redirect(callback_data)
      log_buyer_action('market_configuration_callback', fast_track_id: @public_market.fast_track_id)
      callback_url = build_callback_url(callback_data)
      redirect_to callback_url.to_s, allow_other_host: true
    end

    def handle_missing_callback
      Rails.logger.warn 'No valid callback URL found in session'
      log_buyer_action('market_configuration_confirmed', fast_track_id: @public_market.fast_track_id)
      render :confirmation
    end

    def build_callback_url(callback_data)
      callback_url = URI.parse(callback_data['url'])
      callback_params = build_callback_params(callback_data)
      callback_url.query = callback_params.to_query
      callback_url
    end

    def build_callback_params(callback_data)
      params = {
        fast_track_id: @public_market.fast_track_id,
        market_title: @public_market.title,
        deadline: @public_market.deadline&.iso8601,
        documents_count: @document_requirements.count
      }
      params[:state] = callback_data['state'] if callback_data['state'].present?
      params
    end

    # Debug logging helper methods
    # rubocop:disable Metrics/AbcSize
    def log_new_action_debug
      Rails.logger.info '=== NEW ACTION DEBUG ==='
      Rails.logger.info "All params: #{params.inspect}"
      Rails.logger.info "access_token present: #{params[:access_token].present?}"
      Rails.logger.info "callback_url present: #{params[:callback_url].present?}"
      Rails.logger.info "state present: #{params[:state].present?}"
    end

    def handle_access_token_redirect
      clean_token = params[:access_token].chomp('^') # Clean any corruption
      session[:oauth_access_token] = clean_token
      Rails.logger.info 'Stored access token in session for redirect flow'

      # Redirect to clean URL without token parameter (callback params already stored by before_action)
      Rails.logger.info "Session after token storage: #{session.to_h.inspect}"
      Rails.logger.info "Platform callback in session: #{session[:platform_callback].inspect}"
      redirect_to new_buyer_market_configuration_path
    end

    def log_store_callback_params_debug
      Rails.logger.info '=== STORE CALLBACK PARAMS DEBUG ==='
      Rails.logger.info "All params: #{params.inspect}"
      Rails.logger.info "callback_url param: #{params[:callback_url].inspect}"
      Rails.logger.info "state param: #{params[:state].inspect}"
    end

    def log_confirmation_session_data
      Rails.logger.info "Session callback data: #{session[:platform_callback].inspect}"
      Rails.logger.info "Session ID: #{session.id}"
      Rails.logger.info "All session keys: #{session.keys.inspect}"
      Rails.logger.info "Session data: #{session.to_h.inspect}"
    end
    # rubocop:enable Metrics/AbcSize
  end
end
