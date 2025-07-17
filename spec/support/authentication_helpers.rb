# frozen_string_literal: true

module AuthenticationHelpers
  def sign_in_editor(editor)
    session[:editor_id] = editor.id
  end

  def current_editor
    @current_editor ||= Editor.find(session[:editor_id]) if session[:editor_id]
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :controller
  config.include AuthenticationHelpers, type: :request
end
