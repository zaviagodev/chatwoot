class Captain::Products::SyncService
  def initialize(product:)
    @product = product
  end

  def sync
    return unless @product.formatted_text.present?

    response = find_or_initialize_response
    response.question = build_search_question
    response.answer = @product.formatted_text
    response.status = :approved
    response.save!
    response
  end

  def remove
    @product.responses.destroy_all
  end

  private

  def find_or_initialize_response
    existing = @product.responses.first
    return existing if existing

    Captain::AssistantResponse.new(
      assistant: @product.assistant,
      account: @product.account,
      documentable: @product
    )
  end

  def build_search_question
    parts = [@product.item_name]
    parts << @product.item_code if @product.item_code != @product.item_name
    parts << @product.item_group if @product.item_group.present?
    parts.join(' - ')
  end
end
