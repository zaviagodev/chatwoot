class Captain::PauseExpiryJob < ApplicationJob
  queue_as :default

  def perform(conversation, pause_nonce)
    # Idempotency: only resume if still timed-paused AND nonce matches
    return unless conversation.ai_paused?
    return unless conversation.additional_attributes&.dig('pause_mode') == 'timed'
    return unless conversation.additional_attributes&.dig('pause_nonce') == pause_nonce

    conversation.resume_ai!
    Rails.logger.info("[CAPTAIN][PauseExpiryJob] Auto-resumed conversation #{conversation.id} after timed pause expired")
  end
end
