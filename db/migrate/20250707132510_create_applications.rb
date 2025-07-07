class CreateApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :applications do |t|
      t.string :siret, null: false
      t.string :company_name, null: false
      t.string :email
      t.references :public_market, null: false, foreign_key: true
      t.datetime :submitted_at
      t.string :attestation_path
      t.string :dossier_zip_path
      t.text :form_data
      t.string :status, default: "in_progress", null: false

      t.timestamps
    end

    add_index :applications, :siret
    add_index :applications, [:public_market_id, :siret], unique: true
    add_index :applications, :submitted_at
    add_index :applications, :status
  end
end
