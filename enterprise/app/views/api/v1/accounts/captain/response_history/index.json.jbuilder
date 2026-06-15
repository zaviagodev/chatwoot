json.payload do
  json.array! @responses do |message|
    json.id message.id
    json.content message.content
    json.conversation_id message.conversation_id
    json.conversation_display_id message.conversation&.display_id
    json.created_at message.created_at
    json.approved_by message.content_attributes&.dig('approved_by')
    json.edited message.content_attributes&.dig('edited') || false
    json.model message.content_attributes&.dig('model')
    json.input_tokens message.content_attributes&.dig('input_tokens')
    json.output_tokens message.content_attributes&.dig('output_tokens')
  end
end

json.meta do
  json.total_count @responses_count
  json.page @current_page
end
