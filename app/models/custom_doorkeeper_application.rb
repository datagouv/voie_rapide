# frozen_string_literal: true

class CustomDoorkeeperApplication < ApplicationRecord
  include ::Doorkeeper::Orm::ActiveRecord::Mixins::Application

  self.table_name = 'oauth_applications'

  # Override the authenticate method to validate Editor status
  def self.authenticate(uid, secret)
    app = super
    return nil unless app

    # Check if the associated editor is authorized and active
    editor = Editor.find_by(client_id: uid)
    return nil unless editor&.authorized_and_active?

    app
  end
end
