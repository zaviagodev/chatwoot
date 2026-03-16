json.payload do
  json.array! @reviews do |review|
    json.partial! 'api/v1/models/captain/review', review: review
  end
end

json.meta do
  json.total_count @reviews_count
  json.page @current_page
end
