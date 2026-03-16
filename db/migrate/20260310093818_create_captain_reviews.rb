class CreateCaptainReviews < ActiveRecord::Migration[7.0]
  def change
    create_table :captain_reviews, if_not_exists: true do |t|
      t.references :account, null: false, index: true
      t.references :assistant, null: false, index: true
      t.string :reviewer_name
      t.integer :rating
      t.text :review_text
      t.jsonb :category_tags, default: []
      t.references :captain_product, index: true
      t.timestamps
    end

    add_index :captain_reviews, [:assistant_id, :created_at],
              name: 'idx_captain_reviews_assistant_created'
  end
end
