class AddStatusToCaptainProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :captain_products, :status, :string, default: 'active', null: false
    add_index :captain_products, %i[assistant_id status]
  end
end
