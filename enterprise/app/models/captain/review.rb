class Captain::Review < ApplicationRecord
  self.table_name = 'captain_reviews'

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'
  belongs_to :product, class_name: 'Captain::Product',
             foreign_key: :captain_product_id, optional: true

  has_many_attached :photos

  scope :ordered, -> { order(created_at: :desc) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }

  scope :search, ->(query) {
    where('reviewer_name ILIKE :q OR review_text ILIKE :q', q: "%#{query}%")
  }

  scope :with_category, ->(tag) {
    where('? = ANY(category_tags)', tag)
  }

  def photo_urls
    photos.map do |photo|
      Rails.application.routes.url_helpers.rails_blob_url(photo, only_path: true)
    end
  end

  def product_name
    product&.item_name
  end
end
