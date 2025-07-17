# frozen_string_literal: true

class EditorAuthController < ApplicationController
  # Simple editor authentication for OAuth flows
  # This simulates how an editor platform would authenticate their users

  def new
    # Show editor authentication form
    @editors = Editor.authorized_and_active.order(:name)
  end

  def create
    editor = find_editor_by_params

    if editor_valid?(editor)
      handle_successful_authentication(editor)
    else
      handle_failed_authentication
    end
  end

  private

  def find_editor_by_params
    Editor.find_by(
      id: params[:editor_id],
      client_id: params[:client_id]
    )
  end

  def editor_valid?(editor)
    editor&.authorized? && editor.active?
  end

  def handle_successful_authentication(editor)
    store_editor_session(editor)
    redirect_url = determine_redirect_url
    flash[:success] = "Authentifié en tant qu'éditeur : #{editor.name}"
    redirect_to redirect_url
  end

  def handle_failed_authentication
    flash.now[:error] = I18n.t('editor_auth.invalid_client')
    @editors = Editor.authorized_and_active.order(:name)
    render :new
  end

  def store_editor_session(editor)
    session[:current_editor_id] = editor.id
    session[:current_editor_name] = editor.name
  end

  def determine_redirect_url
    session.delete(:oauth_redirect_url) ||
      params[:redirect_to] ||
      request.referer ||
      root_path
  end

  def destroy
    # Logout editor
    editor_name = session[:current_editor_name]
    session.delete(:current_editor_id)
    session.delete(:current_editor_name)

    flash[:success] = "Déconnecté de l'éditeur : #{editor_name}"
    redirect_to root_path
  end

  def store_oauth_redirect
    # Store the original OAuth URL for after authentication
    return unless request.referer&.include?('oauth/authorize')

    session[:oauth_redirect_url] = request.referer
  end
end
