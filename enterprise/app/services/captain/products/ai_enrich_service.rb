class Captain::Products::AiEnrichService < Llm::BaseAiService
  include Integrations::LlmInstrumentation

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a product copywriter for a customer support AI assistant.
    Write a concise, conversational product description that helps support agents answer customer questions.

    Rules:
    - Keep under 150 words
    - Use a friendly, helpful tone
    - Focus on what customers care about: what it is, what it does, key features, price, and availability
    - Do not include internal codes, SKUs, warehouse names, or technical identifiers
    - Do not use marketing superlatives or make claims you cannot verify
    - Structure as flowing text, not bullet points
    - If stock information is provided, mention availability naturally
  PROMPT

  def initialize(product:)
    super()
    @product = product
  end

  def enrich
    context = build_product_context
    response = instrument_llm_call(instrumentation_params(context)) do
      chat
        .with_instructions(SYSTEM_PROMPT)
        .ask(context)
    end

    usage = Thread.current[:captain_llm_usage] || {}
    {
      enriched_text: response.content&.strip,
      input_tokens: usage[:input_tokens],
      output_tokens: usage[:output_tokens]
    }
  rescue RubyLLM::Error => e
    Rails.logger.error("[AiEnrich] LLM error for product #{@product.item_code}: #{e.message}")
    { error: e.message }
  end

  private

  def build_product_context
    lines = []
    lines << "Product: #{@product.item_name}"
    lines << "Category: #{@product.item_group}" if @product.item_group.present?

    desc = @product.description.to_s.strip
    lines << "Description: #{desc}" if desc.present?

    lines << "Price: #{@product.currency} #{@product.price}" if @product.price.to_f > 0

    if @product.variants.present? && @product.variants.any?
      variant_names = @product.variants.map { |v| v['item_name'] || v[:item_name] }.compact
      lines << "Variants: #{variant_names.join(', ')}" if variant_names.any?
    end

    if @product.specs.present? && @product.specs.any?
      spec_lines = @product.specs.map { |s| "#{s['label'] || s[:label]}: #{s['value'] || s[:value]}" }
      lines << "Specifications: #{spec_lines.join('; ')}" if spec_lines.any?
    end

    stock_text = @product.stock_qty.to_f > 0 ? "In stock (#{@product.stock_qty.to_i} units)" : 'Out of stock'
    lines << "Availability: #{stock_text}"

    lines.join("\n")
  end

  def instrumentation_params(context)
    {
      span_name: 'llm.captain.product_enrich',
      model: @model,
      temperature: @temperature,
      feature_name: 'product_enrich',
      account_id: @product.account_id,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: context }
      ]
    }
  end
end
