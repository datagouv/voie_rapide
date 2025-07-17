# frozen_string_literal: true

# Service to create a market configuration from session data
class MarketConfigurationService
  class Result
    attr_reader :public_market, :fast_track_id, :errors

    def initialize(public_market = nil, errors = [])
      @public_market = public_market
      @fast_track_id = public_market&.fast_track_id
      @errors = errors
    end

    def success?
      errors.empty? && public_market.present?
    end

    def failure?
      !success?
    end
  end

  def initialize(editor, market_configuration_session)
    @editor = editor
    @session = market_configuration_session
  end

  def create!
    validate_inputs!

    ActiveRecord::Base.transaction do
      create_public_market!
      configure_mandatory_documents!
      configure_optional_documents!
    end

    Result.new(@public_market)
  rescue StandardError => e
    Rails.logger.error "Market configuration creation failed: #{e.message}"
    Result.new(nil, [e.message])
  end

  private

  attr_reader :editor, :session

  def validate_inputs!
    raise StandardError, 'Editor must be authorized and active' unless editor.authorized_and_active?
    raise StandardError, 'Market configuration is invalid' unless session.valid?
  end

  def create_public_market!
    @public_market = PublicMarket.create!(
      title: session.title,
      description: session.description,
      deadline: session.deadline,
      market_type: session.market_type,
      editor: editor,
      active: true
    )
  end

  def configure_mandatory_documents!
    mandatory_documents = Document.mandatory_for_market_type(session.market_type)

    mandatory_documents.find_each do |document|
      PublicMarketConfiguration.create!(
        public_market: @public_market,
        document: document,
        required: true
      )
    end
  end

  def configure_optional_documents!
    return if session.optional_document_ids.blank?

    optional_documents = Document.where(id: session.optional_document_ids)

    optional_documents.find_each do |document|
      PublicMarketConfiguration.create!(
        public_market: @public_market,
        document: document,
        required: false
      )
    end
  end
end
