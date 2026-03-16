class CreateConversationContacts < ActiveRecord::Migration[7.1]
  def change
    create_table :conversation_contacts do |t|
      t.references :account, null: false, index: true
      t.references :conversation, null: false, index: true
      t.references :contact, null: false, index: true
      t.timestamps
    end

    add_index :conversation_contacts, [:conversation_id, :contact_id],
              unique: true,
              name: 'index_conversation_contacts_on_conv_and_contact'
  end
end
