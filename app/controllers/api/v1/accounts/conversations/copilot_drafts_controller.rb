class Api::V1::Accounts::Conversations::CopilotDraftsController < Api::V1::Accounts::Conversations::BaseController
  before_action :load_draft, only: [:show, :approve, :reject, :update, :undo_reject]

  def show
    if @draft[:status] == 'rejected'
      return render json: { has_draft: false }
    end

    render json: { has_draft: true, draft: @draft }
  end

  def approve
    @message = @conversation.messages.create!(
      message_type: :outgoing,
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      sender: Current.user,
      content: @draft[:content],
      content_attributes: {
        generated_by: 'captain',
        approved_by: Current.user.name,
        edited: @draft[:edited] || false
      }
    )

    @conversation.clear_copilot_draft!

    broadcast_draft_event('copilot.draft.approved', { message_id: @message.id })

    render json: { message_id: @message.id }, status: :ok
  end

  def reject
    # Soft-delete: mark as rejected with 5-minute TTL
    rejected_draft = @draft.merge(
      status: 'rejected',
      rejected_at: Time.current.iso8601,
      rejected_by: Current.user.name
    )
    draft_key = format(Redis::Alfred::COPILOT_DRAFT_KEY, conversation_id: @conversation.id)
    Redis::Alfred.set(draft_key, rejected_draft.to_json, ex: 300)

    # rubocop:disable Rails/SkipsModelValidations
    @conversation.update_columns(
      additional_attributes: (@conversation.additional_attributes || {}).merge('copilot_draft_pending' => false)
    )
    # rubocop:enable Rails/SkipsModelValidations

    broadcast_draft_event('copilot.draft.rejected', {})
    head :ok
  end

  def undo_reject
    unless @draft[:status] == 'rejected'
      return render json: { error: 'Draft is not in rejected state' }, status: :unprocessable_entity
    end

    restored_draft = @draft.except(:status, :rejected_at, :rejected_by)
    draft_key = format(Redis::Alfred::COPILOT_DRAFT_KEY, conversation_id: @conversation.id)
    Redis::Alfred.set(draft_key, restored_draft.to_json, ex: 3600)

    # rubocop:disable Rails/SkipsModelValidations
    @conversation.update_columns(
      additional_attributes: (@conversation.additional_attributes || {}).merge('copilot_draft_pending' => true)
    )
    # rubocop:enable Rails/SkipsModelValidations

    broadcast_draft_event('copilot.draft.restored', { content: restored_draft[:content] })
    render json: { has_draft: true, draft: restored_draft }, status: :ok
  end

  def update
    new_content = params.require(:content)

    updated_draft = @draft.merge(
      content: new_content,
      edited: true,
      edited_at: Time.current.iso8601
    )

    draft_key = format(Redis::Alfred::COPILOT_DRAFT_KEY, conversation_id: @conversation.id)
    Redis::Alfred.set(draft_key, updated_draft.to_json, ex: 3600)

    broadcast_draft_event('copilot.draft.edited', { content: new_content })

    render json: { has_draft: true, draft: updated_draft }
  end

  private

  def load_draft
    draft_key = format(Redis::Alfred::COPILOT_DRAFT_KEY, conversation_id: @conversation.id)
    draft_json = Redis::Alfred.get(draft_key)

    return render_not_found_error('No copilot draft found') if draft_json.blank?

    @draft = JSON.parse(draft_json, symbolize_names: true)
  end

  def broadcast_draft_event(event_name, additional_data)
    tokens = collect_broadcast_tokens
    return if tokens.blank?

    ::ActionCableBroadcastJob.perform_later(
      tokens,
      event_name,
      {
        conversation_id: @conversation.id,
        conversation_display_id: @conversation.display_id,
        account_id: @conversation.account_id
      }.merge(additional_data)
    )
  end

  def collect_broadcast_tokens
    agent_tokens = @conversation.inbox.members.pluck(:pubsub_token)
    admin_tokens = @conversation.account.administrators.pluck(:pubsub_token)
    (agent_tokens + admin_tokens).uniq
  end
end
