# == Schema Information
#
# Table name: conversation_contacts
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :bigint           not null
#  contact_id      :bigint           not null
#
# Indexes
#
#  index_conversation_contacts_on_conv_and_contact  (conversation_id,contact_id) UNIQUE
#

class ConversationContact < ApplicationRecord
  validates :account_id, presence: true
  validates :conversation_id, presence: true
  validates :contact_id, presence: true
  validates :contact_id, uniqueness: { scope: [:conversation_id] }

  belongs_to :account
  belongs_to :conversation
  belongs_to :contact

  before_validation :ensure_account_id

  private

  def ensure_account_id
    self.account_id = conversation&.account_id
  end
end
