class Captain::Products::StockSyncService
  DEFAULT_SYNC_INTERVAL = 3600

  def initialize(assistant:)
    @assistant = assistant
  end

  def sync
    products = @assistant.products.select(:id, :item_code, :stock_qty)
    return { synced_count: 0 } if products.empty?

    stock_data = fetch_stock_batch(products.map(&:item_code))
    return handle_api_error(stock_data[:error]) if stock_data.is_a?(Hash) && stock_data[:error]

    synced_count = update_changed_products(products, stock_data)
    record_success(synced_count)
  end

  private

  def fetch_stock_batch(item_codes)
    erp_client = Captain::Erp::ApiClient.new(assistant: @assistant)
    erp_client.get_stock_batch(item_codes: item_codes)
  end

  def update_changed_products(products, stock_data)
    manage_service = Captain::Products::ManageService.new(assistant: @assistant, account: @assistant.account)
    count = 0

    products.each do |product|
      new_qty = stock_data[product.item_code]
      next if new_qty.nil?
      next if product.stock_qty.to_f == new_qty.to_f

      manage_service.update_stock(product.reload, new_qty)
      count += 1
    rescue StandardError => e
      Rails.logger.error("[StockSync] Failed to update product #{product.item_code}: #{e.message}")
    end

    count
  end

  def handle_api_error(message)
    error_count = (@assistant.sync_error_count || 0).to_i + 1
    @assistant.sync_error_count = error_count
    @assistant.save!
    { error: message, sync_error_count: error_count }
  end

  def record_success(synced_count)
    @assistant.sync_error_count = 0
    @assistant.last_synced_at = Time.current.iso8601
    @assistant.save!
    { synced_count: synced_count, last_synced_at: @assistant.last_synced_at }
  end
end
