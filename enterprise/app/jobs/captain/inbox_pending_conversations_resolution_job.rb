class Captain::InboxPendingConversationsResolutionJob < ApplicationJob
  queue_as :low

  def perform(inbox)
    Current.executed_by = inbox.captain_assistant

    resolvable_conversations = inbox.conversations.pending.where('last_activity_at < ? ', Time.now.utc - 1.hour).limit(Limits::BULK_ACTIONS_LIMIT)
    resolvable_conversations.each do |conversation|
      # Skip conversations in copilot draft mode — auto-resolve requires human approval
      next if conversation.respond_to?(:copilot_draft?) && conversation.copilot_draft?

      create_outgoing_message(conversation, inbox)
      conversation.resolved!
    end
  ensure
    Current.reset
  end

  private

  def create_outgoing_message(conversation, inbox)
    resolution_message = inbox.captain_assistant.config['resolution_message']
    return if resolution_message.blank?

    I18n.with_locale(inbox.account.locale) do
      conversation.messages.create!(
        {
          message_type: :outgoing,
          account_id: conversation.account_id,
          inbox_id: conversation.inbox_id,
          content: resolution_message,
          sender: inbox.captain_assistant
        }
      )
    end
  end
end
