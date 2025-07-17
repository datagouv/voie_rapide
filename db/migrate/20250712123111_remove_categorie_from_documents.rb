class RemoveCategorieFromDocuments < ActiveRecord::Migration[8.0]
  def change
    remove_column :documents, :categorie, :string
  end
end
