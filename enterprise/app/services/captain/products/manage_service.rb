class Captain::Products::ManageService
  def initialize(assistant:, account:)
    @assistant = assistant
    @account = account
  end

  # Create a product from ERPNext API response data
  def create(product_data)
    product = @assistant.products.build(
      account: @account,
      item_code: product_data[:item_code],
      item_name: product_data[:item_name],
      description: product_data[:description],
      price: product_data[:price],
      currency: product_data[:currency],
      stock_qty: product_data[:stock_qty] || 0,
      stock_status: derive_stock_status(product_data[:stock_qty]),
      item_group: product_data[:item_group],
      image_url: product_data[:image],
      variants: product_data[:variants] || [],
      specs: product_data[:specs] || [],
      erp_company: product_data[:erp_company] || @assistant.erp_company,
      description_source: product_data.fetch(:description_source, 'auto'),
      status: product_data.fetch(:status, 'active')
    )

    # Use ERPNext pre-formatted text, fallback to local format
    format_service = Captain::Products::FormatService.new(product: product)
    product.formatted_text = format_service.from_api_response(product_data[:formatted_text])

    product.save!

    # Sync to knowledge base
    Captain::Products::SyncService.new(product: product).sync

    product
  end

  # Update product data (e.g., re-sync from ERPNext).
  # Uses fetch() with product fallback instead of || operator to preserve falsy values
  # like price=0 or stock_qty=0.
  def update(product, product_data, reset_source: false)
    new_variants = product_data.key?(:variants) ? merge_variants(product.variants, product_data[:variants]) : product.variants

    attrs = {
      item_name: product_data.fetch(:item_name, product.item_name),
      description: product_data.fetch(:description, product.description),
      price: product_data.fetch(:price, product.price),
      currency: product_data.fetch(:currency, product.currency),
      stock_qty: product_data.fetch(:stock_qty, product.stock_qty),
      stock_status: derive_stock_status(product_data.fetch(:stock_qty, product.stock_qty)),
      item_group: product_data.fetch(:item_group, product.item_group),
      image_url: product_data.fetch(:image, product.image_url),
      variants: new_variants,
      specs: product_data.fetch(:specs, product.specs),
      status: product_data.fetch(:status, product.status),
      description_source: reset_source ? 'auto' : product_data.fetch(:description_source, product.description_source)
    }

    product.assign_attributes(attrs)

    # Re-format
    format_service = Captain::Products::FormatService.new(product: product)
    product.formatted_text = format_service.from_api_response(product_data[:formatted_text])

    product.save!

    # Re-sync to knowledge base
    Captain::Products::SyncService.new(product: product).sync

    product
  end

  # Update only stock data (lightweight, no full re-format)
  def update_stock(product, stock_qty)
    product.stock_qty = stock_qty.to_f
    product.stock_status = derive_stock_status(stock_qty)

    # Re-format locally (only stock line changes)
    format_service = Captain::Products::FormatService.new(product: product)
    product.formatted_text = format_service.local_format

    product.save!

    # Re-sync to knowledge base
    Captain::Products::SyncService.new(product: product).sync

    product
  end

  # Update description text directly (manual or AI edit)
  def update_description(product, text:, source:)
    product.update!(
      formatted_text: text,
      description_source: source
    )

    # Re-sync to knowledge base
    Captain::Products::SyncService.new(product: product).sync

    product
  end

  # Remove product and its knowledge base entry
  def destroy(product)
    Captain::Products::SyncService.new(product: product).remove
    product.destroy!
  end

  private

  def derive_stock_status(qty)
    return 'unknown' if qty.nil?

    qty.to_f > 0 ? 'in_stock' : 'out_of_stock'
  end

  # Merge new ERP variants with existing Captain state.
  # Preserves enabled, price_override, description_override from existing data.
  # New variants from ERP default to enabled: true.
  def merge_variants(existing, incoming)
    return incoming if existing.blank?
    return existing if incoming.blank?

    existing_map = existing.index_by { |v| v['item_code'] || v[:item_code] }

    incoming.map do |new_v|
      code = new_v['item_code'] || new_v[:item_code]
      old_v = existing_map[code]

      if old_v
        enabled = old_v.key?('enabled') ? old_v['enabled'] : (old_v.key?(:enabled) ? old_v[:enabled] : true)
        new_v.merge(
          'enabled' => enabled,
          'price_override' => old_v['price_override'] || old_v[:price_override],
          'description_override' => old_v['description_override'] || old_v[:description_override]
        )
      else
        new_v.merge('enabled' => true)
      end
    end
  end
end
