class Line::SendOnLineService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Line
  end

  def perform_reply
    target_id = reply_target_id
    response = channel.client.push_message(target_id, build_payload)

    return if response.blank?

    parsed_json = JSON.parse(response.body)

    if response.code == '200'
      # If the request is successful, update the message status to delivered
      Messages::StatusUpdateService.new(message, 'delivered').perform
    else
      # If the request is not successful, update the message status to failed and save the external error
      Messages::StatusUpdateService.new(message, 'failed', external_error(parsed_json)).perform
    end
  end

  def reply_target_id
    conversation = message.conversation
    if conversation.conversation_type_group? && conversation.line_group_id.present?
      conversation.line_group_id
    else
      conversation.contact_inbox.source_id
    end
  end

  def build_payload
    if message.content_type == 'cards'
      build_card_payload
    elsif message.content_type == 'input_select' && message.content_attributes['items'].any?
      build_input_select_payload
    else
      build_text_payload
    end
  end

  def build_text_payload
    if message.content && message.attachments.any?
      [text_message, *attachments]
    elsif message.content.nil? && message.attachments.any?
      attachments
    else
      text_message
    end
  end

  def attachments
    message.attachments.map do |attachment|
      # Support only image and video for now, https://developers.line.biz/en/reference/messaging-api/#image-message
      next unless attachment.file_type == 'image' || attachment.file_type == 'video'

      {
        type: attachment.file_type,
        originalContentUrl: attachment.download_url,
        previewImageUrl: attachment.download_url
      }
    end
  end

  # https://developers.line.biz/en/reference/messaging-api/#text-message
  def text_message
    {
      type: 'text',
      text: message.outgoing_content
    }
  end

  # https://developers.line.biz/en/reference/messaging-api/#flex-message
  def build_input_select_payload
    {
      type: 'flex',
      altText: message.content,
      contents: {
        type: 'bubble',
        body: {
          type: 'box',
          layout: 'vertical',
          contents: [
            {
              type: 'text',
              text: message.content,
              wrap: true
            },
            *input_select_to_button
          ]
        }
      }
    }
  end

  # https://developers.line.biz/en/reference/messaging-api/#flex-message
  def build_card_payload
    attrs = message.content_attributes || {}

    # Carousel mode (multiple products)
    if attrs['products'].is_a?(Array) && attrs['products'].length > 1
      bubbles = attrs['products'].first(12).map { |product| build_card_bubble(product, attrs) }
      return {
        type: 'flex',
        altText: message.content&.truncate(400) || 'Your order',
        contents: { type: 'carousel', contents: bubbles }
      }
    end

    # Single product/checkout card
    product = attrs['product'] || attrs['products']&.first || {}
    {
      type: 'flex',
      altText: message.content&.truncate(400) || 'Your order',
      contents: build_card_bubble(product, attrs)
    }
  end

  def build_card_bubble(product, attrs)
    design = resolve_card_design(attrs['design_id'])
    sections = design.dig('sections') || {}
    colors = design.dig('colors') || {}
    bg_color = sanitize_hex(colors['background'], '#FFFFFF')
    accent = sanitize_hex(colors['accent'], '#06C755')

    bubble = { type: 'bubble', size: 'kilo' }
    bubble[:styles] = { body: { backgroundColor: bg_color }, footer: { backgroundColor: bg_color } }

    # Hero image
    hero_cfg = sections['hero'] || {}
    image_url = product['image_url'].to_s
    if hero_cfg['enabled'] != false && image_url.start_with?('https://')
      ratio = hero_cfg['aspect_ratio'] || '20:13'
      bubble[:hero] = {
        type: 'image',
        url: image_url,
        size: 'full',
        aspectRatio: ratio,
        aspectMode: 'cover'
      }
    end

    # Body contents
    body_contents = []

    # Title
    title_cfg = sections['title'] || { 'enabled' => true, 'size' => 'lg', 'weight' => 'bold' }
    if title_cfg['enabled'] != false
      title_text = product['item_name'] || attrs['title'] || 'Your Order'
      body_contents << {
        type: 'text',
        text: title_text.to_s.truncate(100),
        weight: title_cfg['weight'] == 'bold' ? 'bold' : 'regular',
        size: flex_size(title_cfg['size']),
        wrap: true,
        color: auto_text_color(bg_color)
      }
    end

    # Subtitle
    subtitle_cfg = sections['subtitle'] || {}
    subtitle_text = product['subtitle'] || attrs['subtitle']
    if subtitle_cfg['enabled'] && subtitle_text.present?
      body_contents << {
        type: 'text',
        text: subtitle_text.to_s.truncate(200),
        size: flex_size(subtitle_cfg['size']),
        wrap: true,
        color: sanitize_hex(subtitle_cfg['color'], '#999999'),
        margin: 'sm'
      }
    end

    # Price
    price_cfg = sections['price'] || {}
    price_val = product['price'] || product['grand_total'] || attrs['grand_total']
    if price_cfg['enabled'] != false && price_val.present?
      currency = product['currency'] || 'THB'
      formatted = format_price(price_val, currency)
      body_contents << {
        type: 'text',
        text: formatted,
        size: flex_size(price_cfg['size']),
        weight: 'bold',
        color: sanitize_hex(price_cfg['color'], '#06C755'),
        margin: 'md'
      }
    end

    bubble[:body] = { type: 'box', layout: 'vertical', contents: body_contents, paddingAll: '16px' } if body_contents.any?

    # Button / footer
    button_cfg = sections['button'] || {}
    action_url = (product['storefront_url'] || product['checkout_url'] || attrs['checkout_url']).to_s
    if button_cfg['enabled'] != false && action_url.start_with?('https://')
      label = (button_cfg['label'] || 'View').to_s.truncate(20)
      is_primary = button_cfg['style'] != 'link'
      bubble[:footer] = {
        type: 'box',
        layout: 'vertical',
        contents: [{
          type: 'button',
          style: is_primary ? 'primary' : 'link',
          color: is_primary ? accent : nil,
          action: { type: 'uri', label: label, uri: action_url },
          height: 'sm'
        }.compact],
        paddingAll: '12px'
      }
    end

    bubble
  end

  def resolve_card_design(design_id)
    return default_checkout_design if design_id.blank?

    account = message.conversation&.account
    design = account&.card_designs&.find_by(id: design_id)
    return default_checkout_design unless design

    design.increment_usage!
    design.design_json || default_checkout_design
  end

  def default_checkout_design
    {
      'sections' => {
        'hero' => { 'enabled' => true, 'aspect_ratio' => '20:13' },
        'title' => { 'enabled' => true, 'size' => 'lg', 'weight' => 'bold' },
        'subtitle' => { 'enabled' => true, 'size' => 'sm', 'color' => '#999999' },
        'price' => { 'enabled' => true, 'size' => 'lg', 'color' => '#06C755' },
        'button' => { 'enabled' => true, 'label' => 'ชำระเงิน', 'style' => 'primary' }
      },
      'colors' => { 'background' => '#FFFFFF', 'accent' => '#06C755' }
    }
  end

  FLEX_SIZE_MAP = { 'sm' => 'sm', 'md' => 'md', 'lg' => 'lg', 'xl' => 'xl' }.freeze

  def flex_size(size)
    FLEX_SIZE_MAP[size] || 'md'
  end

  def sanitize_hex(hex, fallback)
    return fallback unless hex.is_a?(String) && hex.match?(/\A#[0-9A-Fa-f]{6}\z/)

    hex
  end

  def auto_text_color(bg_hex)
    # BT.601 luminance — light bg gets dark text, dark bg gets light text
    hex = sanitize_hex(bg_hex, '#FFFFFF').delete('#')
    r = hex[0..1].to_i(16) / 255.0
    g = hex[2..3].to_i(16) / 255.0
    b = hex[4..5].to_i(16) / 255.0
    luminance = 0.299 * r + 0.587 * g + 0.114 * b
    luminance < 0.6 ? '#FFFFFF' : '#111111'
  end

  def format_price(amount, currency)
    num = amount.to_f
    formatted = num == num.to_i ? num.to_i.to_s : format('%.2f', num)
    # Add thousand separators
    parts = formatted.split('.')
    parts[0] = parts[0].gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
    "#{currency} #{parts.join('.')}"
  end

  def input_select_to_button
    message.content_attributes['items'].map do |item|
      {
        type: 'button',
        style: 'link',
        height: 'sm',
        action: {
          type: 'message',
          label: item['title'],
          text: item['value']
        }
      }
    end
  end

  # https://developers.line.biz/en/reference/messaging-api/#error-responses
  def external_error(error)
    # Message containing information about the error. See https://developers.line.biz/en/reference/messaging-api/#error-messages
    message = error['message']
    # An array of error details. If the array is empty, this property will not be included in the response.
    details = error['details']

    return message if details.blank?

    detail_messages = details.map { |detail| "#{detail['property']}: #{detail['message']}" }
    [message, detail_messages].join(', ')
  end
end
