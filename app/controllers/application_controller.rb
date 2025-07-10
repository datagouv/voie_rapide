# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  protected

  # Helper method to get current editor in session
  def current_editor
    @current_editor ||= session[:current_editor_id] ? Editor.find_by(id: session[:current_editor_id]) : nil
  end

  helper_method :current_editor

  # Helper method to check if an editor is authenticated
  def editor_authenticated?
    current_editor.present?
  end

  helper_method :editor_authenticated?
end
