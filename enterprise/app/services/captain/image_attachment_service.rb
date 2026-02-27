class Captain::ImageAttachmentService
  MAX_IMAGES = 4

  def initialize(assistant:)
    @assistant = assistant
  end

  # Returns an array of ActiveStorage::Blob objects (max 4)
  def find_photo_blobs(query)
    return [] if query.blank?

    translated_query = translate_query(query)

    # Direct review matches (existing)
    review_responses = search_review_responses(translated_query)
    review_blobs = collect_photo_blobs(review_responses)

    # Product-linked review matches (new — find photos from reviews linked to matched products)
    product_linked_blobs = collect_product_linked_review_blobs(translated_query)

    # Combine, dedup by blob id, cap at MAX_IMAGES
    (review_blobs + product_linked_blobs).uniq(&:id).first(MAX_IMAGES)
  end

  private

  def translate_query(query)
    Captain::Llm::TranslateQueryService
      .new(account: @assistant.account)
      .translate(query, target_language: @assistant.account.locale_english_name)
  rescue StandardError => e
    Rails.logger.warn "[Captain] Query translation failed, using raw query: #{e.message}"
    query
  end

  def search_review_responses(query)
    @assistant.responses.approved
              .where(documentable_type: 'Captain::Review')
              .search(query, account_id: @assistant.account_id)
  end

  def collect_photo_blobs(review_responses)
    review_ids = review_responses.filter_map(&:documentable_id).uniq
    return [] if review_ids.empty?

    reviews = Captain::Review.where(id: review_ids).with_attached_photos
    reviews.flat_map { |r| r.photos.map(&:blob) }.first(MAX_IMAGES)
  end

  # Finds photos from reviews linked to products matching the query
  def collect_product_linked_review_blobs(query)
    product_responses = @assistant.responses.approved
                                  .where(documentable_type: 'Captain::Product')
                                  .search(query, account_id: @assistant.account_id)
    return [] if product_responses.empty?

    product_ids = product_responses.filter_map(&:documentable_id).uniq
    # Scope to @assistant to prevent cross-assistant data leakage
    reviews = @assistant.reviews.where(captain_product_id: product_ids).with_attached_photos
    reviews.flat_map { |r| r.photos.map(&:blob) }
  rescue StandardError => e
    Rails.logger.warn "[Captain] Product-linked review photo lookup failed: #{e.message}"
    [] # Graceful fallback — still return direct review photos
  end
end
