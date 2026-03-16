class CreateCardDesigns < ActiveRecord::Migration[7.1]
  def change
    create_table :card_designs do |t|
      t.references :account, null: false, index: true
      t.string :name, null: false
      t.jsonb :design_json, null: false, default: {}
      t.boolean :is_default, default: false, null: false
      t.boolean :is_builtin, default: false, null: false
      t.integer :usage_count, default: 0, null: false
      t.timestamps
    end

    add_index :card_designs, [:account_id, :name], unique: true,
              name: 'index_card_designs_on_account_id_and_name'
    add_index :card_designs, [:account_id, :is_default],
              name: 'index_card_designs_on_account_id_and_is_default'
  end
end
