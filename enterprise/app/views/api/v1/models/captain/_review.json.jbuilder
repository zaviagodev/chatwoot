json.id review.id
json.reviewer_name review.reviewer_name
json.rating review.rating
json.review_text review.review_text
json.category_tags review.category_tags
json.captain_product_id review.captain_product_id
json.product_name review.product_name
json.photo_urls review.photo_urls
json.photos review.photos.map { |p| { signed_id: p.signed_id, url: Rails.application.routes.url_helpers.rails_blob_url(p, only_path: true) } }
json.assistant_id review.assistant_id
json.account_id review.account_id
json.created_at review.created_at
json.updated_at review.updated_at
