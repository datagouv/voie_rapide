class CreatePublicMarkets < ActiveRecord::Migration[8.0]
  def change
    create_table :public_markets do |t|
      t.string :title, null: false
      t.text :description
      t.datetime :deadline, null: false
      t.string :fast_track_id, null: false
      t.string :market_type, null: false
      t.references :editor, null: false, foreign_key: true
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :public_markets, :fast_track_id, unique: true
    add_index :public_markets, :deadline
    add_index :public_markets, [:editor_id, :created_at]
  end
end
