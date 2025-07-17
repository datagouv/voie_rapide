class AddAppAuthenticationToEditors < ActiveRecord::Migration[8.0]
  def change
    add_column :editors, :app_authentication_enabled, :boolean, default: true, null: false
    add_column :editors, :app_token_expires_at, :datetime
    add_column :editors, :app_token_last_used_at, :datetime
    
    add_index :editors, :app_authentication_enabled
    add_index :editors, :app_token_expires_at
  end
end
