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
end
