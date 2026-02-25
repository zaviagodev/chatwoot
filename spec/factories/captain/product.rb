FactoryBot.define do
  factory :captain_product, class: 'Captain::Product' do
    association :assistant, factory: :captain_assistant
    association :account
    sequence(:item_code) { |n| "ITEM-#{n.to_s.rjust(3, '0')}" }
    sequence(:item_name) { |n| "Test Product #{n}" }
    description { 'A test product description' }
    price { 100.00 }
    currency { 'THB' }
    stock_qty { 50 }
    stock_status { 'in_stock' }
    item_group { 'Test Products' }
    formatted_text { "Test Product\nCategory: Test Products\nPrice: THB 100.00\nStock: In stock (50 available)" }
    description_source { 'auto' }

    trait :out_of_stock do
      stock_qty { 0 }
      stock_status { 'out_of_stock' }
    end

    trait :ai_enriched do
      description_source { 'ai' }
      formatted_text { 'AI-enriched description of this amazing product.' }
    end

    trait :manual do
      description_source { 'manual' }
      formatted_text { 'Manually written product description.' }
    end

    trait :with_variants do
      variants { [{ 'item_code' => 'VAR-001', 'item_name' => 'Red', 'image' => nil }] }
    end

    trait :with_specs do
      specs { [{ 'label' => 'Weight', 'value' => '500g' }] }
    end
  end
end
