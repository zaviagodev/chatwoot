class AddCopilotDefaultModeToCaptainInboxes < ActiveRecord::Migration[7.0]
  def change
    add_column :captain_inboxes, :copilot_default_mode, :string, default: 'draft', null: false
  end
end
