class Captain::Products::FormatService
  def initialize(product:)
    @product = product
  end

  # Use pre-formatted text from ERPNext API response
  def from_api_response(formatted_text)
    formatted_text.presence || local_format
  end

  # Build formatted text locally from stored product data
  def local_format
    lines = []
    lines << @product.item_name
    lines << "Category: #{@product.item_group}" if @product.item_group.present?

    desc = strip_html(@product.description.to_s).strip
    if desc.present?
      words = desc.split
      desc = words.first(50).join(' ') + '...' if words.length > 50
      lines << "Description: #{desc}"
    end

    if @product.price.to_f > 0
      lines << "Price: #{@product.currency} #{format_price(@product.price)}"
    end

    format_variants(lines)
    format_specs(lines)
    format_stock(lines)

    lines.join("\n")
  end

  private

  def strip_html(text)
    ActionView::Base.full_sanitizer.sanitize(text).to_s
  end

  def format_price(price)
    number_with_delimiter(price.to_f.round(2))
  end

  def number_with_delimiter(number)
    parts = number.to_s.split('.')
    parts[0] = parts[0].reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    parts.join('.')
  end

  def format_variants(lines)
    variants = @product.variants || []
    return if variants.empty?

    enabled = variants.select { |v| v['enabled'] != false && v[:enabled] != false }
    disabled = variants.reject { |v| v['enabled'] != false && v[:enabled] != false }

    lines << ''
    lines << "Variants (#{enabled.length} of #{variants.length} enabled):"

    enabled.each do |v|
      name = v['item_name'] || v[:item_name] || 'Unknown'
      price = v['price_override'] || v[:price_override] || v['price'] || v[:price]
      qty = (v['stock_qty'] || v[:stock_qty] || 0).to_f
      attrs = (v['attributes'] || v[:attributes] || [])
        .map { |a| "#{a['attribute'] || a[:attribute]}: #{a['value'] || a[:value]}" }

      price_str = price.to_f > 0 ? "#{@product.currency} #{format_price(price)}" : ''
      price_str += ' (custom)' if v['price_override'] || v[:price_override]
      stock_str = qty > 0 ? "In stock (#{qty.to_i})" : 'Out of stock'

      parts = [name, price_str, stock_str].reject(&:blank?)
      lines << "  - #{parts.join(' | ')}"
      lines << "    #{attrs.join(', ')}" if attrs.any?

      desc_override = v['description_override'] || v[:description_override]
      lines << "    #{desc_override}" if desc_override.present?

      img = v['image'] || v[:image]
      lines << '    [has image]' if img.present?
    end

    if disabled.any?
      names = disabled.map { |v| v['item_name'] || v[:item_name] }.compact.first(10)
      lines << ''
      lines << "(#{disabled.length} variants disabled: #{names.join(', ')})"
    end
  end

  def format_specs(lines)
    specs = @product.specs || []
    return if specs.empty?

    spec_strs = specs.first(5).map { |s| "#{s['label'] || s[:label]}: #{s['value'] || s[:value]}" }
    lines << "Specs: #{spec_strs.join('; ')}" if spec_strs.any?
  end

  def format_stock(lines)
    qty = @product.stock_qty.to_f
    if qty > 0
      lines << "Stock: In stock (#{qty.to_i} available)"
    else
      lines << 'Stock: Out of stock'
    end
  end
end
