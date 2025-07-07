class RenameConfigurationTablesToPublicMarketConfigurations < ActiveRecord::Migration[8.0]
  def change
    rename_table :tender_configurations, :public_market_configurations
  end
end
