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

  def handle_response(response)
    return { error: 'ERPNext request failed', status: response.code } unless response.success?

    response.parsed_response&.dig('message') || {}
  end
end
