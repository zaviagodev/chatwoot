class AddOptionGroupsToCaptainProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :captain_products, :option_groups, :jsonb, default: []
  end
end
