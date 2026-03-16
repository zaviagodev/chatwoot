FactoryBot.define do
  factory :card_design do
    account
    sequence(:name) { |n| "Card Design #{n}" }
    design_json do
      {
        'sections' => {
          'hero' => { 'enabled' => true, 'aspect_ratio' => '20:13' },
          'title' => { 'enabled' => true, 'size' => 'lg', 'weight' => 'bold' },
          'subtitle' => { 'enabled' => false, 'size' => 'md', 'color' => '#999999' },
          'price' => { 'enabled' => true, 'size' => 'md', 'color' => '#666666' },
          'button' => { 'enabled' => true, 'label' => 'View Product', 'style' => 'primary' }
        },
        'colors' => { 'background' => '#FFFFFF', 'accent' => '#06C755' }
      }
    end

    trait :builtin do
      is_builtin { true }
    end

    trait :default do
      is_default { true }
    end
  end
end
