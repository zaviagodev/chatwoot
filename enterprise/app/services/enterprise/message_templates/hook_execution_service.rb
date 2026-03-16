module Enterprise::MessageTemplates::HookExecutionService
  MAX_ATTACHMENT_WAIT_SECONDS = 4
  CAPTAIN_DEBOUNCE_WINDOW = 5.seconds
  CAPTAIN_DEBOUNCE_TTL = 120 # Safety net TTL; ensure block handles normal cleanup
  CAPTAIN_DEBOUNCE_ENABLED = ActiveModel::Type::Boolean.new.cast(ENV.fetch('CAPTAIN_DEBOUNCE_ENABLED', 'true'))
  CAPTAIN_COPILOT_MODE_ENABLED = ActiveModel::Type::Boolean.new.cast(ENV.fetch('CAPTAIN_COPILOT_MODE_ENABLED', 'false'))

  def trigger_templates
    super
    return unless should_process_captain_response?
    return perform_handoff unless inbox.captain_active?

    schedule_captain_response
  end

  def should_send_greeting?
    return false if captain_handling_conversation?

    super
  end

  def should_send_out_of_office_message?
    return false if captain_handling_conversation?

    super
  end

  def should_send_email_collect?
    return false if captain_handling_conversation?

    super
  end

  private

  def schedule_captain_response
    job_args = [conversation, conversation.inbox.captain_assistant]

    # Copilot: when a draft is pending and a new message arrives, clear the old draft and regenerate.
    # The frontend's draft history (pushToHistory) preserves the old draft for browsing.
    if CAPTAIN_COPILOT_MODE_ENABLED && conversation.copilot_draft? && conversation.additional_attributes&.dig('copilot_draft_pending')
      Rails.logger.info("[CAPTAIN] New message while draft pending — clearing old draft to regenerate for conversation: #{conversation.id}")
      conversation.clear_copilot_draft!
    end

    # Feature flag: set CAPTAIN_DEBOUNCE_ENABLED=false in .env to disable debounce and revert to immediate dispatch
    unless CAPTAIN_DEBOUNCE_ENABLED
      Captain::Conversation::ResponseBuilderJob.perform_later(*job_args)
      return
    end

    captain_key = format(Redis::Alfred::CAPTAIN_RESPONSE_KEY, conversation_id: conversation.id)

    # Atomic lock: only the first message in a burst enqueues a job.
    # Follows the same pattern as SendEmailNotificationService.
    return unless Redis::Alfred.set(captain_key, message.id, nx: true, ex: CAPTAIN_DEBOUNCE_TTL)

    wait_time = CAPTAIN_DEBOUNCE_WINDOW
    wait_time += calculate_attachment_wait_time if message.attachments.present?

    Captain::Conversation::ResponseBuilderJob.set(wait: wait_time).perform_later(*job_args)
  end

  def calculate_attachment_wait_time
    attachment_count = message.attachments.size
    base_wait = 1.second

    # Wait longer for more attachments or larger files
    additional_wait = [attachment_count * 1, MAX_ATTACHMENT_WAIT_SECONDS].min.seconds
    base_wait + additional_wait
  end

  def should_process_captain_response?
    return false unless message.incoming? && inbox.captain_assistant.present?

    if CAPTAIN_COPILOT_MODE_ENABLED
      !conversation.copilot_off?
    else
      conversation.pending?
    end
  end

  def perform_handoff
    if CAPTAIN_COPILOT_MODE_ENABLED
      return if conversation.copilot_off?
    else
      return unless conversation.pending?
    end

    Rails.logger.info("Captain limit exceeded, performing handoff for conversation: #{conversation.id}")
    conversation.messages.create!(
      message_type: :outgoing,
      account_id: conversation.account.id,
      inbox_id: conversation.inbox.id,
      content: 'Transferring to another agent for further assistance.'
    )
    conversation.bot_handoff! if conversation.pending?
    conversation.update_copilot_mode!('off') if CAPTAIN_COPILOT_MODE_ENABLED
    send_out_of_office_message_after_handoff
  end

  def send_out_of_office_message_after_handoff
    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(conversation)
  end

  def captain_handling_conversation?
    return false unless inbox.respond_to?(:captain_assistant) && inbox.captain_assistant.present?

    if CAPTAIN_COPILOT_MODE_ENABLED
      !conversation.copilot_off?
    else
      conversation.pending?
    end
  end
end
