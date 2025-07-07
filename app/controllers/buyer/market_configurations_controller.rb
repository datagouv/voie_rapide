# frozen_string_literal: true

module Buyer
  # Controller for market configuration flow
  # Handles the two-step process: market type selection and document configuration
  class MarketConfigurationsController < BaseController
    before_action :configure_iframe_response
    before_action :set_market_configuration, only: %i[show documents create confirm]
    before_action :validate_market_type, only: %i[documents create]

    # Step 1: Market type selection
    def new
      @market_configuration = MarketConfigurationSession.new
      @market_types = available_market_types

      log_buyer_action('market_configuration_started')

      render :market_type_selection
    end

    # Process market type selection and show documents
    def documents
      @market_configuration.market_type = market_type_params[:market_type]

      unless @market_configuration.valid_market_type?
        redirect_to new_buyer_market_configuration_path, alert: 'Please select a valid market type'
        return
      end

      @mandatory_documents = Document.mandatory_for_market_type(@market_configuration.market_type)
      @optional_documents = Document.optional_for_market_type(@market_configuration.market_type)

      log_buyer_action('market_type_selected', market_type: @market_configuration.market_type)

      render :document_selection
    end

    # Create final market configuration
    def create
      @market_configuration.attributes = market_configuration_params

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

      log_buyer_action('market_configuration_confirmed', fast_track_id: @public_market.fast_track_id)

      render :confirmation
    end

    private

    def set_market_configuration
      @market_configuration = MarketConfigurationSession.new(session[:market_configuration] || {})
    end

    def market_type_params
      params.require(:market_configuration).permit(:market_type)
    end

    def market_configuration_params
      params.require(:market_configuration).permit(:title, :description, :deadline, :market_type, optional_document_ids: [])
    end

    def validate_market_type
      return if @market_configuration.market_type.present?

      redirect_to new_buyer_market_configuration_path, alert: 'Please select a market type first'
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
        flash.now[:alert] = 'Failed to create market configuration'
        render :document_selection
      end
    end

    def handle_invalid_configuration
      load_document_lists
      flash.now[:alert] = 'Please correct the errors below'
      render :document_selection
    end

    def load_document_lists
      @mandatory_documents = Document.mandatory_for_market_type(@market_configuration.market_type)
      @optional_documents = Document.optional_for_market_type(@market_configuration.market_type)
    end

    # Store configuration in session for multi-step flow
    def persist_market_configuration
      session[:market_configuration] = @market_configuration.to_h
    end
  end
end
