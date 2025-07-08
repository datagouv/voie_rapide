class AddCandidateFieldsToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :phone, :string
    add_column :applications, :contact_person, :string
    add_column :applications, :submission_id, :string
    
    add_index :applications, :submission_id, unique: true
  end
end
