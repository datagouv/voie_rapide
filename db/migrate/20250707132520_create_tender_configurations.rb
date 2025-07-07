class CreateTenderConfigurations < ActiveRecord::Migration[8.0]
  def change
    create_table :tender_configurations do |t|
      t.references :public_market, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.boolean :required, default: true, null: false

      t.timestamps
    end

    add_index :tender_configurations, [:public_market_id, :document_id], unique: true
    add_index :tender_configurations, :required
  end
end
