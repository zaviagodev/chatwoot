module Enterprise::MessageTemplates::HookExecutionService
  MAX_ATTACHMENT_WAIT_SECONDS = 4
  CAPTAIN_DEBOUNCE_WINDOW = 5.seconds
  CAPTAIN_DEBOUNCE_TTL = 120 # Safety net TTL; ensure block handles normal cleanup
  CAPTAIN_DEBOUNCE_ENABLED = ActiveModel::Type::Boolean.new.cast(ENV.fetch('CAPTAIN_DEBOUNCE_ENABLED', 'true'))

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
    conversation.pending? && message.incoming? && inbox.captain_assistant.present?
  end

  def perform_handoff
    return unless conversation.pending?

    Rails.logger.info("Captain limit exceeded, performing handoff mid-conversation for conversation: #{conversation.id}")
    conversation.messages.create!(
      message_type: :outgoing,
      account_id: conversation.account.id,
      inbox_id: conversation.inbox.id,
      content: 'Transferring to another agent for further assistance.'
    )
    conversation.bot_handoff!
    send_out_of_office_message_after_handoff
  end

  def send_out_of_office_message_after_handoff
    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(conversation)
  end

  def captain_handling_conversation?
    conversation.pending? && inbox.respond_to?(:captain_assistant) && inbox.captain_assistant.present?
  end
end
