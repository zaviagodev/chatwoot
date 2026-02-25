class Captain::Products::ToolProvisioningService
  TOOL_SLUGS = %w[custom_order_status custom_stock_check custom_customer_account].freeze

  # NOTE: Frappe wraps all @frappe.whitelist() returns in {"message": <return_value>}.
  # So the Liquid `response` variable is {"message": {"data": ...}}.
  # All templates must access response.message.data, NOT response.data.

  ORDER_STATUS_RESPONSE_TEMPLATE = <<~LIQUID.freeze
    {% if response.message.data.size > 0 %}{% for order in response.message.data %}
    Order {{ order.order_id }}: {{ order.status }}
    Customer: {{ order.customer_name }}
    Date: {{ order.order_date }}{% if order.delivery_date %} | Expected delivery: {{ order.delivery_date }}{% endif %}
    Total: {{ order.currency }} {{ order.total }}
    Items:{% for item in order.items %}
    - {{ item.name }} x{{ item.qty }} ({{ item.amount }}){% endfor %}
    {% endfor %}{% else %}{{ response.message.message }}{% endif %}
  LIQUID

  STOCK_CHECK_RESPONSE_TEMPLATE = <<~LIQUID.freeze
    {% for item in response.message.data %}{{ item.item_code }}: {% if item.in_stock %}In stock ({{ item.qty }} available){% else %}Out of stock{% endif %}
    {% endfor %}
  LIQUID

  CUSTOMER_ACCOUNT_RESPONSE_TEMPLATE = <<~LIQUID.freeze
    {% if response.message.data %}Customer: {{ response.message.data.customer_name }}
    Email: {{ response.message.data.email }}
    Member since: {{ response.message.data.member_since }}
    Total orders: {{ response.message.data.total_orders }} | Total spent: {{ response.message.data.currency }} {{ response.message.data.total_spent }}
    {% if response.message.data.recent_orders.size > 0 %}Recent orders:{% for order in response.message.data.recent_orders %}
    - {{ order.order_id }} ({{ order.status }}) - {{ order.currency }} {{ order.total }} on {{ order.order_date }}{% endfor %}{% endif %}
    {% else %}{{ response.message.message }}{% endif %}
  LIQUID

  SCENARIO_INSTRUCTION = <<~INSTRUCTION.freeze
    You help customers with product-related questions. Use these tools:
    - [Order Status](tool://custom_order_status) - when a customer asks about their order status, tracking, or delivery
    - [Stock Check](tool://custom_stock_check) - when a customer asks about exact stock availability or wants to know if a specific quantity is available
    - [Customer Account](tool://custom_customer_account) - when you need to look up a customer's order history or account information

    Always ask for the customer's order number or email before using these tools.
    If a tool call fails, say "I'm unable to look that up right now. Let me connect you with our team."
  INSTRUCTION

  def initialize(assistant:)
    @assistant = assistant
    @account = assistant.account
  end

  def provision_tools
    validate_config!

    tools = tool_configs.map do |config|
      create_or_update_tool(config)
    end

    scenario = provision_scenario

    { provisioned_count: tools.size, tools: tools.map(&:to_tool_metadata), scenario_id: scenario.id }
  end

  def deprovision_tools
    removed = @account.captain_custom_tools.where(slug: TOOL_SLUGS).destroy_all
    @assistant.scenarios.where(title: 'Product Support').destroy_all
    { removed_count: removed.size }
  end

  private

  def validate_config!
    raise ArgumentError, 'erp_tenant_key is not configured on this assistant' if @assistant.erp_tenant_key.blank?
    raise ArgumentError, 'ERP_TENANT_SERVER_URL environment variable is not set' if base_url.blank?
    raise ArgumentError, 'ERP_TENANT_SERVER_API_KEY environment variable is not set' if api_key.blank?
  end

  def base_url
    ENV.fetch('ERP_TENANT_SERVER_URL', nil)
  end

  def api_key
    ENV.fetch('ERP_TENANT_SERVER_API_KEY', nil)
  end

  def tenant_key
    @assistant.erp_tenant_key
  end

  def create_or_update_tool(config)
    tool = Captain::CustomTool.find_or_initialize_by(slug: config[:slug], account: @account)
    tool.assign_attributes(config.except(:slug))
    tool.save!
    tool
  end

  def provision_scenario
    Captain::Scenario.find_or_create_by!(
      assistant: @assistant,
      account: @account,
      title: 'Product Support'
    ) do |s|
      s.description = 'Handles product inquiries, order lookups, and stock checks using ERPNext data'
      s.instruction = SCENARIO_INSTRUCTION
      s.enabled = true
    end
  end

  def tool_configs
    [
      {
        slug: 'custom_order_status',
        title: 'Order Status Lookup',
        description: 'Look up order status by order number or customer email. Returns order details including status, items, and delivery information.',
        endpoint_url: "#{base_url}/api/method/zaviago_backend.api.captain_tools.get_order_status",
        http_method: 'POST',
        param_schema: [
          { 'name' => 'order_id', 'type' => 'string', 'description' => 'Order number (e.g., SO-001). Pass empty string if unknown.', 'required' => true },
          { 'name' => 'customer_email', 'type' => 'string', 'description' => 'Customer email address. Pass empty string if unknown.', 'required' => true }
        ],
        request_template: build_request_template(%w[order_id customer_email]),
        response_template: ORDER_STATUS_RESPONSE_TEMPLATE,
        auth_type: 'api_key',
        auth_config: { 'key' => api_key, 'location' => 'header', 'name' => 'X-API-Key' },
        enabled: true
      },
      {
        slug: 'custom_stock_check',
        title: 'Stock Check',
        description: 'Check current stock availability for one or more products by item code. Returns quantity and in-stock status.',
        endpoint_url: "#{base_url}/api/method/zaviago_backend.api.captain_tools.get_stock_batch",
        http_method: 'POST',
        param_schema: [
          { 'name' => 'item_codes', 'type' => 'string', 'description' => 'Comma-separated item codes to check stock for', 'required' => true }
        ],
        request_template: build_request_template(%w[item_codes]),
        response_template: STOCK_CHECK_RESPONSE_TEMPLATE,
        auth_type: 'api_key',
        auth_config: { 'key' => api_key, 'location' => 'header', 'name' => 'X-API-Key' },
        enabled: true
      },
      {
        slug: 'custom_customer_account',
        title: 'Customer Account Lookup',
        description: 'Look up customer account information by email. Returns customer name, order history, total spend, and membership date.',
        endpoint_url: "#{base_url}/api/method/zaviago_backend.api.captain_tools.get_customer_info",
        http_method: 'POST',
        param_schema: [
          { 'name' => 'customer_email', 'type' => 'string', 'description' => 'Customer email address', 'required' => true }
        ],
        request_template: build_request_template(%w[customer_email]),
        response_template: CUSTOMER_ACCOUNT_RESPONSE_TEMPLATE,
        auth_type: 'api_key',
        auth_config: { 'key' => api_key, 'location' => 'header', 'name' => 'X-API-Key' },
        enabled: true
      }
    ]
  end

  # Bake tenant_key as a literal value in the request template.
  # Liquid strict_variables only receives LLM-provided params, so tenant_key
  # must be a literal string, not a {{ variable }}.
  def build_request_template(param_names)
    pairs = [%("tenant_key": "#{tenant_key}")]
    param_names.each do |name|
      pairs << %("#{name}": "{{ #{name} }}")
    end
    "{#{pairs.join(', ')}}"
  end
end
