class CreateEditors < ActiveRecord::Migration[8.0]
  def change
    create_table :editors do |t|
      t.string :name, null: false
      t.string :client_id, null: false
      t.string :client_secret, null: false
      t.string :callback_url, null: false
      t.boolean :authorized, default: false, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :editors, :client_id, unique: true
    add_index :editors, :name, unique: true
  end
end
