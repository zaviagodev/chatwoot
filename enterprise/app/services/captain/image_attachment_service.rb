class Captain::ImageAttachmentService
  MAX_IMAGES = 4

  def initialize(assistant:)
    @assistant = assistant
  end

  # Returns an array of ActiveStorage::Blob objects (max 4)
  def find_photo_blobs(query)
    return [] if query.blank?

    translated_query = translate_query(query)
    review_responses = search_review_responses(translated_query)
    return [] if review_responses.empty?

    collect_photo_blobs(review_responses)
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
    review_ids = review_responses.map(&:documentable_id).compact.uniq
    return [] if review_ids.empty?

    reviews = Captain::Review.where(id: review_ids).with_attached_photos
    reviews.flat_map { |r| r.photos.map(&:blob) }.first(MAX_IMAGES)
  end
end
