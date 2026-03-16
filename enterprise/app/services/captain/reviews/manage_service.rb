class Captain::Reviews::ManageService
  def initialize(assistant:, account:)
    @assistant = assistant
    @account = account
  end

  def create(review_params)
    review = @assistant.reviews.build(
      account: @account,
      reviewer_name: review_params[:reviewer_name],
      rating: review_params[:rating],
      review_text: review_params[:review_text],
      category_tags: review_params[:category_tags] || [],
      captain_product_id: review_params[:captain_product_id].presence
    )

    attach_photos(review, review_params[:photos])
    review.save!
    review
  end

  def update(review, review_params)
    review.assign_attributes(
      reviewer_name: review_params[:reviewer_name],
      rating: review_params[:rating],
      review_text: review_params[:review_text],
      category_tags: review_params[:category_tags] || [],
      captain_product_id: review_params[:captain_product_id].presence
    )

    remove_photos(review, review_params[:removed_photo_signed_ids])
    attach_photos(review, review_params[:photos])
    review.save!
    review
  end

  def destroy(review)
    review.photos.purge if review.photos.attached?
    review.destroy!
  end

  private

  def attach_photos(review, photos)
    return if photos.blank?

    photos.each do |photo|
      review.photos.attach(photo) if photo.present?
    end
  end

  def remove_photos(review, signed_ids)
    return if signed_ids.blank?

    signed_ids.each do |signed_id|
      blob = ActiveStorage::Blob.find_signed(signed_id)
      review.photos.find { |p| p.blob_id == blob.id }&.purge if blob
    rescue ActiveStorage::InvalidSignedIdError
      next
    end
  end
end
