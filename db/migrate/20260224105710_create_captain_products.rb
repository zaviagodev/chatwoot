class CreateCaptainProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :captain_products do |t|
      t.references :account, null: false, index: true
      t.references :assistant, null: false, index: true
      t.string :item_code, null: false
      t.string :item_name, null: false
      t.text :description
      t.decimal :price, precision: 18, scale: 2
      t.string :currency
      t.decimal :stock_qty, precision: 18, scale: 2, default: 0
      t.string :stock_status, default: 'unknown'
      t.string :item_group
      t.string :image_url
      t.jsonb :variants, default: []
      t.jsonb :specs, default: []
      t.text :formatted_text
      t.string :description_source, default: 'auto'
      t.string :erp_company
      t.timestamps
    end

    add_index :captain_products, [:account_id, :assistant_id, :item_code], unique: true,
              name: 'idx_captain_products_unique_item'
    add_index :captain_products, [:assistant_id, :item_group],
              name: 'idx_captain_products_assistant_group'
  end
end
