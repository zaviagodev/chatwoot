# ref : https://developers.line.biz/en/docs/messaging-api/receiving-messages/#webhook-event-types
# https://developers.line.biz/en/reference/messaging-api/#message-event

class Line::IncomingMessageService
  include ::FileTypeHelper
  pattr_initialize [:inbox!, :params!]
  LINE_STICKER_IMAGE_URL = 'https://stickershop.line-scdn.net/stickershop/v1/sticker/%s/android/sticker.png'.freeze

  def perform
    # probably test events
    return if params[:events].blank?

    parse_events
  end

  private

  def parse_events
    params[:events].each do |event|
      next unless supported_event?(event)

      if member_event?(event)
        handle_member_event(event)
        next
      end

      next unless event_type_message?(event)

      source_type = event.dig('source', 'type')

      if source_type == 'group'
        handle_group_message(event)
      else
        handle_direct_message(event)
      end
    end
  end

  def handle_direct_message(event)
    get_line_contact_info(event)
    return if @line_contact_info['userId'].blank?

    set_contact
    set_conversation

    return unless message_created?(event)

    attach_files event['message']
    @message.save!
  end

  def handle_group_message(event)
    group_id = event.dig('source', 'groupId')
    user_id = event.dig('source', 'userId')
    return if group_id.blank? || user_id.blank?

    get_line_contact_info(event)
    return if @line_contact_info['userId'].blank?

    set_contact
    set_group_conversation(group_id)
    ensure_conversation_contact

    return unless message_created?(event)

    attach_files event['message']
    @message.save!
  end

  def handle_member_event(event)
    group_id = event.dig('source', 'groupId')
    return if group_id.blank?

    conversation = find_group_conversation(group_id)
    return unless conversation

    event_type = event['type']
    members = event.dig('joined', 'members') || event.dig('left', 'members') || []

    members.each do |member|
      user_id = member['userId']
      next if user_id.blank?

      if event_type == 'memberJoined'
        handle_member_joined(conversation, user_id)
      elsif event_type == 'memberLeft'
        handle_member_left(conversation, user_id)
      end
    end
  end

  def handle_member_joined(conversation, user_id)
    contact = find_or_create_contact_by_line_id(user_id)
    ConversationContact.find_or_create_by!(conversation: conversation, contact: contact)
    create_system_message(conversation, "#{contact.name} joined the group")
  end

  def handle_member_left(conversation, user_id)
    contact_inbox = inbox.contact_inboxes.find_by(source_id: user_id)
    return unless contact_inbox

    conversation.conversation_contacts.where(contact: contact_inbox.contact).destroy_all
    create_system_message(conversation, "#{contact_inbox.contact.name} left the group")
  end

  def create_system_message(conversation, content)
    conversation.messages.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :activity,
      content: content
    )
  end

  def find_or_create_contact_by_line_id(user_id)
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: user_id,
      inbox: inbox,
      contact_attributes: fetch_line_profile(user_id)
    ).perform
    contact_inbox.contact
  end

  def fetch_line_profile(user_id)
    profile = JSON.parse(inbox.channel.client.get_profile(user_id).body)
    {
      name: profile['displayName'],
      avatar_url: profile['pictureUrl'],
      additional_attributes: { social_line_user_id: user_id }
    }
  rescue StandardError
    { name: user_id, additional_attributes: { social_line_user_id: user_id } }
  end

  def supported_event?(event)
    event_type_message?(event) || member_event?(event)
  end

  def member_event?(event)
    %w[memberJoined memberLeft].include?(event['type'])
  end

  def find_group_conversation(group_id)
    account.conversations.where(inbox: inbox, line_group_id: group_id, conversation_type: :group).first
  end

  def set_group_conversation(group_id)
    @conversation = find_group_conversation(group_id)
    return if @conversation

    group_info = fetch_group_summary(group_id)

    @conversation = ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      conversation_type: :group,
      line_group_id: group_id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: {
        group_name: group_info[:name],
        group_icon_url: group_info[:icon_url]
      }
    )
  end

  def ensure_conversation_contact
    ConversationContact.find_or_create_by!(conversation: @conversation, contact: @contact)
  end

  def fetch_group_summary(group_id)
    response = inbox.channel.client.get_group_summary(group_id)
    summary = JSON.parse(response.body)
    { name: summary['groupName'], icon_url: summary['pictureUrl'] }
  rescue StandardError
    { name: "LINE Group #{group_id[0..7]}", icon_url: nil }
  end

  def message_created?(event)
    @message = @conversation.messages.build(
      content: message_content(event),
      account_id: @inbox.account_id,
      content_type: message_content_type(event),
      inbox_id: @inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: event['message']['id'].to_s
    )
    @message
  end

  def message_content(event)
    message_type = event.dig('message', 'type')
    case message_type
    when 'text'
      event.dig('message', 'text')
    when 'sticker'
      sticker_id = event.dig('message', 'stickerId')
      sticker_image_url(sticker_id)
    end
  end

  # Currently, Chatwoot doesn't support stickers. As a temporary solution,
  # we're displaying stickers as images using the sticker ID in markdown format.
  # This is subject to change in the future. We've chosen not to download and display the sticker as an image because the sticker's information
  # and images are the property of the creator or legal owner. We aim to avoid storing it on our server without their consent.
  # If there are any permission or rendering issues, the URL may break, and we'll display the sticker ID as text instead.
  # Ref: https://developers.line.biz/en/reference/messaging-api/#wh-sticker
  def sticker_image_url(sticker_id)
    "![sticker-#{sticker_id}](#{LINE_STICKER_IMAGE_URL % sticker_id})"
  end

  def message_content_type(event)
    return 'sticker' if event['message']['type'] == 'sticker'

    'text'
  end

  def attach_files(message)
    return unless message_type_non_text?(message['type'])

    response = inbox.channel.client.get_message_content(message['id'])

    extension = get_file_extension(response)
    file_name = message['fileName'] || "media-#{message['id']}.#{extension}"
    temp_file = Tempfile.new(file_name)
    temp_file.binmode
    temp_file << response.body
    temp_file.rewind

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_content_type(response),
      file: {
        io: temp_file,
        filename: file_name,
        content_type: response.content_type
      }
    )
  end

  def get_file_extension(response)
    if response.content_type&.include?('/')
      response.content_type.split('/')[1]
    else
      'bin'
    end
  end

  def event_type_message?(event)
    event['type'] == 'message' || event['type'] == 'sticker'
  end

  def message_type_non_text?(type)
    [
      Line::Bot::Event::MessageType::Video,
      Line::Bot::Event::MessageType::Audio,
      Line::Bot::Event::MessageType::Image,
      Line::Bot::Event::MessageType::File
    ].include?(type)
  end

  def account
    @account ||= inbox.account
  end

  def get_line_contact_info(event)
    @line_contact_info = JSON.parse(inbox.channel.client.get_profile(event['source']['userId']).body)
  end

  def set_contact
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: @line_contact_info['userId'],
      inbox: inbox,
      contact_attributes: contact_attributes
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def conversation_params
    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    }
  end

  def set_conversation
    @conversation = @contact_inbox.conversations.first
    return if @conversation

    @conversation = ::Conversation.create!(conversation_params)
  end

  def contact_attributes
    {
      name: @line_contact_info['displayName'],
      avatar_url: @line_contact_info['pictureUrl'],
      additional_attributes: additional_attributes
    }
  end

  def additional_attributes
    {
      social_line_user_id: @line_contact_info['userId']
    }
  end

  def file_content_type(file_content)
    file_type(file_content.content_type)
  end
end
