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

    names = variants.first(10).map { |v| v['item_name'] || v[:item_name] }.compact
    lines << "Variants: #{names.join(', ')}" if names.any?
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
