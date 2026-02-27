json.id review.id
json.reviewer_name review.reviewer_name
json.rating review.rating
json.review_text review.review_text
json.category_tags review.category_tags
json.captain_product_id review.captain_product_id
json.product_name review.product&.item_name
json.photo_urls review.photos.map { |photo| url_for(photo) }
json.photos review.photos.map { |photo| { url: url_for(photo), signed_id: photo.signed_id } }
json.assistant_id review.assistant_id
json.account_id review.account_id
json.created_at review.created_at
json.updated_at review.updated_at
