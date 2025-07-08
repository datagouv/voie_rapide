# frozen_string_literal: true

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

      # Check if market is still active and within deadline
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

    def clear_candidate_session
      session.delete(:siret)
      session.delete(:application_id)
      session.delete(:fast_track_id)
    end
  end
end
