# == Schema Information
#
# Table name: captain_inboxes
#
#  id                   :bigint           not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  captain_assistant_id :bigint           not null
#  inbox_id             :bigint           not null
#
# Indexes
#
#  index_captain_inboxes_on_captain_assistant_id               (captain_assistant_id)
#  index_captain_inboxes_on_captain_assistant_id_and_inbox_id  (captain_assistant_id,inbox_id) UNIQUE
#  index_captain_inboxes_on_inbox_id                           (inbox_id)
#
class CaptainInbox < ApplicationRecord
  COPILOT_MODES = %w[draft auto_send off].freeze

  belongs_to :captain_assistant, class_name: 'Captain::Assistant'
  belongs_to :inbox

  validates :inbox_id, uniqueness: true
  validates :copilot_default_mode, inclusion: { in: COPILOT_MODES }

  after_update :propagate_copilot_mode, if: :saved_change_to_copilot_default_mode?

  private

  # Centralized propagation: when an admin changes the inbox default mode,
  # all existing conversations are updated to match. This prevents stale
  # conversations from staying on the old mode after a settings change.
  def propagate_copilot_mode
    new_mode = copilot_default_mode
    inbox.conversations.find_each do |conversation|
      merged = (conversation.additional_attributes || {}).merge('copilot_mode' => new_mode)
      conversation.update_columns(additional_attributes: merged)
    end
    Rails.logger.info "[Captain] Propagated copilot_mode=#{new_mode} to all conversations in inbox #{inbox_id}"
  end
end
