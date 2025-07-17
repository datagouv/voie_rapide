class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.string :nom, null: false
      t.text :description
      t.boolean :obligatoire, default: false, null: false
      t.string :categorie, null: false
      t.string :type_marche
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :documents, :categorie
    add_index :documents, :type_marche
    add_index :documents, [ :categorie, :type_marche ]
    add_index :documents, :obligatoire
  end
end
