class AddGroupChatSupportToConversations < ActiveRecord::Migration[7.1]
  def change
    # Add conversation_type enum: 0 = direct (default), 1 = group
    add_column :conversations, :conversation_type, :integer, default: 0, null: false
    # LINE group ID for deduplicating group conversations
    add_column :conversations, :line_group_id, :string

    add_index :conversations, :conversation_type
    add_index :conversations, :line_group_id

    # Allow contact_id to be null for group conversations
    change_column_null :conversations, :contact_id, true
  end
end
