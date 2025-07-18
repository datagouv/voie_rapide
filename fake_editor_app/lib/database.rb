# frozen_string_literal: true

require 'sequel'

# Initialize database connection
db_path = File.join(File.dirname(__FILE__), '..', 'fake_editor.db')
DB = Sequel.sqlite(db_path)

# Create tables
DB.create_table?(:tokens) do
  primary_key :id
  String :access_token, null: false
  Integer :expires_in, null: false
  String :token_type, null: false
  String :scope
  DateTime :created_at, null: false
  DateTime :expires_at, null: false
end

class Token < Sequel::Model(DB[:tokens])
  def self.current_token
    where { expires_at > Time.now }.order(:created_at).last
  end

  def self.store_token(access_token:, expires_in:, token_type:, scope:)
    # Clear old tokens
    clear_tokens

    # Store new token
    create(
      access_token: access_token,
      expires_in: expires_in,
      token_type: token_type,
      scope: scope,
      created_at: Time.now,
      expires_at: Time.now + expires_in.to_i
    )
  end

  def self.clear_tokens
    dataset.delete
  end

  def expired?
    expires_at < Time.now
  end

  def valid?
    !expired?
  end

  def time_until_expiry
    return 0 if expired?

    (expires_at - Time.now).to_i
  end
end
