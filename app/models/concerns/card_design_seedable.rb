module CardDesignSeedable
  extend ActiveSupport::Concern

  BUILTIN_DESIGNS = [
    {
      name: 'Product',
      is_default: true,
      design_json: {
        'sections' => {
          'hero' => { 'enabled' => true, 'aspect_ratio' => '20:13' },
          'title' => { 'enabled' => true, 'size' => 'lg', 'weight' => 'bold' },
          'subtitle' => { 'enabled' => false, 'size' => 'md', 'color' => '#999999' },
          'price' => { 'enabled' => true, 'size' => 'md', 'color' => '#666666' },
          'button' => { 'enabled' => true, 'label' => 'View Product', 'style' => 'primary' }
        },
        'colors' => { 'background' => '#FFFFFF', 'accent' => '#06C755' }
      }
    },
    {
      name: 'Promotion',
      is_default: false,
      design_json: {
        'sections' => {
          'hero' => { 'enabled' => true, 'aspect_ratio' => '20:13' },
          'title' => { 'enabled' => true, 'size' => 'xl', 'weight' => 'bold' },
          'subtitle' => { 'enabled' => true, 'size' => 'md', 'color' => '#FFFFFF' },
          'price' => { 'enabled' => true, 'size' => 'lg', 'color' => '#FFFFFF' },
          'button' => { 'enabled' => true, 'label' => 'Shop Now', 'style' => 'primary' }
        },
        'colors' => { 'background' => '#E8453C', 'accent' => '#FFFFFF' }
      }
    },
    {
      name: 'Event',
      is_default: false,
      design_json: {
        'sections' => {
          'hero' => { 'enabled' => true, 'aspect_ratio' => '20:13' },
          'title' => { 'enabled' => true, 'size' => 'xl', 'weight' => 'bold' },
          'subtitle' => { 'enabled' => true, 'size' => 'md', 'color' => '#999999' },
          'price' => { 'enabled' => false, 'size' => 'md', 'color' => '#666666' },
          'button' => { 'enabled' => true, 'label' => 'Learn More', 'style' => 'primary' }
        },
        'colors' => { 'background' => '#FFFFFF', 'accent' => '#4A90D9' }
      }
    },
    {
      name: 'Announcement',
      is_default: false,
      design_json: {
        'sections' => {
          'hero' => { 'enabled' => false, 'aspect_ratio' => '20:13' },
          'title' => { 'enabled' => true, 'size' => 'xl', 'weight' => 'bold' },
          'subtitle' => { 'enabled' => true, 'size' => 'md', 'color' => '#666666' },
          'price' => { 'enabled' => false, 'size' => 'md', 'color' => '#666666' },
          'button' => { 'enabled' => true, 'label' => 'Read More', 'style' => 'link' }
        },
        'colors' => { 'background' => '#F5F5F5', 'accent' => '#333333' }
      }
    }
  ].freeze

  class_methods do
    def seed_builtin_designs_for(account)
      BUILTIN_DESIGNS.each do |design_data|
        account.card_designs.find_or_create_by!(
          name: design_data[:name],
          is_builtin: true
        ) do |design|
          design.design_json = design_data[:design_json]
          design.is_default = design_data[:is_default]
        end
      end
    end
  end
end
