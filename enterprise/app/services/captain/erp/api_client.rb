class Captain::Erp::ApiClient
  BASE_PATH = '/api/method/zaviago_backend.api.captain_tools'.freeze
  TIMEOUT = 10
  BATCH_TIMEOUT = 15
  BATCH_SIZE = 100

  def initialize(assistant:)
    @assistant = assistant
    @base_url = ENV.fetch('ERP_TENANT_SERVER_URL')
    @api_key = ENV.fetch('ERP_TENANT_SERVER_API_KEY')
  end

  def search_products(query: nil, item_group: nil, page: 1, page_size: 20)
    post('search_products', tenant_key: tenant_key, query: query, item_group: item_group, limit: page_size, start: (page - 1) * page_size)
  end

  def get_item_groups
    post('get_categories', tenant_key: tenant_key)
  end

  def get_warehouses
    post('get_warehouses', tenant_key: tenant_key)
  end

  def create_shared_checkout(items:, customer_email: nil, address_name: nil,
                             address_data: nil, line_user_id: nil, register_customer: nil)
    post_to('zaviago_backend.storefront.shared_checkout.create_shared_checkout',
            tenant_key: tenant_key, items: items,
            customer_email: customer_email, address_name: address_name,
            address_data: address_data, line_user_id: line_user_id,
            register_customer: register_customer)
  end

  def lookup_line_customer(line_user_id:)
    post_to('zaviago_backend.storefront.shared_checkout.lookup_line_customer',
            tenant_key: tenant_key, line_user_id: line_user_id)
  end

  def search_thai_address(query:)
    post_to('zaviago_backend.storefront.shared_checkout.search_thai_address_proxy',
            tenant_key: tenant_key, query: query)
  end

  def get_product_detail(item_code:)
    post('get_product_detail', tenant_key: tenant_key, item_code: item_code)
  end

  def get_stock_batch(item_codes:, warehouse: nil)
    results = {}
    item_codes.each_slice(BATCH_SIZE) do |batch|
      response = post('get_stock_batch', tenant_key: tenant_key, item_codes: batch.join(','), timeout: BATCH_TIMEOUT)
      return response if response.is_a?(Hash) && response[:error]

      # Response: {"data": [{"item_code": "X", "qty": 10, "in_stock": true}]}
      # Convert array format to flat hash: {"ITEM-001" => 20, "ITEM-002" => 0}
      items = response.is_a?(Hash) ? (response['data'] || []) : []
      items.each { |item| results[item['item_code']] = item['qty'] } if items.is_a?(Array)
    end
    results
  end

  private

  def tenant_key
    @assistant.erp_tenant_key
  end

  def post(endpoint, params)
    request_timeout = params.delete(:timeout) || TIMEOUT
    response = HTTParty.post(
      "#{@base_url}#{BASE_PATH}.#{endpoint}",
      body: params.compact.to_json,
      headers: { 'Content-Type' => 'application/json', 'X-API-Key' => @api_key },
      timeout: request_timeout
    )
    handle_response(response)
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
    { error: "ERPNext connection failed: #{e.class.name}", status: 503 }
  end

  def post_to(full_method, params)
    request_timeout = params.delete(:timeout) || TIMEOUT
    response = HTTParty.post(
      "#{@base_url}/api/method/#{full_method}",
      body: params.compact.to_json,
      headers: { 'Content-Type' => 'application/json', 'X-API-Key' => @api_key },
      timeout: request_timeout
    )
    handle_response(response)
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
    { error: "ERPNext connection failed: #{e.class.name}", status: 503 }
  end

  def handle_response(response)
    unless response.success?
      parsed = response.parsed_response
      frappe_msg = extract_frappe_error(parsed)
      return { error: frappe_msg || 'ERPNext request failed', status: response.code }
    end

    response.parsed_response&.dig('message') || {}
  end

  def extract_frappe_error(parsed)
    return nil unless parsed.is_a?(Hash)

    server_messages = parsed['_server_messages']
    return nil unless server_messages.is_a?(String)

    messages = JSON.parse(server_messages)
    return nil unless messages.is_a?(Array) && messages.any?

    # Frappe double-encodes: outer array of JSON strings, each is a JSON object with 'message' key
    first_msg = JSON.parse(messages.first)
    first_msg.is_a?(Hash) ? first_msg['message'] : first_msg.to_s
  rescue JSON::ParserError
    nil
  end
end
