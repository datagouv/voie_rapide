# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include Rails.application.routes.url_helpers

      protect_from_forgery with: :null_session
      before_action :set_content_type

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActionController::ParameterMissing, with: :render_bad_request
      rescue_from StandardError, with: :render_internal_server_error

      private

      def set_content_type
        response.headers['Content-Type'] = 'application/json'
      end

      def render_not_found(exception = nil)
        render json: {
          error: 'not_found',
          error_description: exception&.message || 'Resource not found'
        }, status: :not_found
      end

      def render_bad_request(exception = nil)
        render json: {
          error: 'bad_request',
          error_description: exception&.message || 'Invalid request parameters'
        }, status: :bad_request
      end

      def render_internal_server_error(exception = nil)
        Rails.logger.error "API Error: #{exception&.message}"
        Rails.logger.error "Backtrace: #{exception&.backtrace&.join("\n")}" if exception

        render json: {
          error: 'internal_server_error',
          error_description: 'An unexpected error occurred'
        }, status: :internal_server_error
      end
    end
  end
end
