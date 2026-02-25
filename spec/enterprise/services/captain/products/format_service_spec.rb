require 'rails_helper'

RSpec.describe Captain::Products::FormatService do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }

  describe '#from_api_response' do
    it 'returns the provided text when present' do
      product = build(:captain_product, assistant: assistant, account: account)
      service = described_class.new(product: product)
      result = service.from_api_response('Pre-formatted text from API')
      expect(result).to eq('Pre-formatted text from API')
    end

    it 'falls back to local_format when text is nil' do
      product = build(:captain_product, assistant: assistant, account: account, item_name: 'Fallback Product')
      service = described_class.new(product: product)
      result = service.from_api_response(nil)
      expect(result).to include('Fallback Product')
    end

    it 'falls back to local_format when text is empty string' do
      product = build(:captain_product, assistant: assistant, account: account, item_name: 'Fallback Product')
      service = described_class.new(product: product)
      result = service.from_api_response('')
      expect(result).to include('Fallback Product')
    end
  end

  describe '#local_format' do
    it 'includes product name as first line' do
      product = build(:captain_product, assistant: assistant, account: account, item_name: 'Jasmine Tea')
      service = described_class.new(product: product)
      lines = service.local_format.split("\n")
      expect(lines.first).to eq('Jasmine Tea')
    end

    it 'includes category when item_group is present' do
      product = build(:captain_product, assistant: assistant, account: account, item_group: 'Beverages')
      service = described_class.new(product: product)
      expect(service.local_format).to include('Category: Beverages')
    end

    it 'omits category when item_group is nil' do
      product = build(:captain_product, assistant: assistant, account: account, item_group: nil)
      service = described_class.new(product: product)
      expect(service.local_format).not_to include('Category:')
    end

    it 'includes formatted price' do
      product = build(:captain_product, assistant: assistant, account: account,
                                        price: 1250.50, currency: 'THB')
      service = described_class.new(product: product)
      expect(service.local_format).to include('Price: THB 1,250.5')
    end

    it 'omits price when zero' do
      product = build(:captain_product, assistant: assistant, account: account, price: 0)
      service = described_class.new(product: product)
      expect(service.local_format).not_to include('Price:')
    end

    it 'handles missing description gracefully' do
      product = build(:captain_product, assistant: assistant, account: account, description: nil)
      service = described_class.new(product: product)
      expect(service.local_format).not_to include('Description:')
    end

    it 'strips HTML from description' do
      product = build(:captain_product, assistant: assistant, account: account,
                                        description: '<p>Bold <b>text</b> here</p>')
      service = described_class.new(product: product)
      result = service.local_format
      expect(result).to include('Description: Bold text here')
      expect(result).not_to include('<p>')
      expect(result).not_to include('<b>')
    end

    it 'truncates long descriptions at 50 words' do
      long_desc = ('word ' * 60).strip
      product = build(:captain_product, assistant: assistant, account: account, description: long_desc)
      service = described_class.new(product: product)
      result = service.local_format
      desc_line = result.split("\n").find { |l| l.start_with?('Description:') }
      expect(desc_line).to end_with('...')
    end

    it 'includes variants when present' do
      product = build(:captain_product, :with_variants, assistant: assistant, account: account)
      service = described_class.new(product: product)
      expect(service.local_format).to include('Variants: Red')
    end

    it 'omits variants when empty' do
      product = build(:captain_product, assistant: assistant, account: account, variants: [])
      service = described_class.new(product: product)
      expect(service.local_format).not_to include('Variants:')
    end

    it 'includes specs when present' do
      product = build(:captain_product, :with_specs, assistant: assistant, account: account)
      service = described_class.new(product: product)
      expect(service.local_format).to include('Specs: Weight: 500g')
    end

    it 'omits specs when empty' do
      product = build(:captain_product, assistant: assistant, account: account, specs: [])
      service = described_class.new(product: product)
      expect(service.local_format).not_to include('Specs:')
    end

    it 'shows in stock with quantity when stock_qty > 0' do
      product = build(:captain_product, assistant: assistant, account: account, stock_qty: 42)
      service = described_class.new(product: product)
      expect(service.local_format).to include('Stock: In stock (42 available)')
    end

    it 'shows out of stock when stock_qty is 0' do
      product = build(:captain_product, :out_of_stock, assistant: assistant, account: account)
      service = described_class.new(product: product)
      expect(service.local_format).to include('Stock: Out of stock')
    end

    it 'handles all fields missing gracefully' do
      product = build(:captain_product,
                      assistant: assistant, account: account,
                      item_name: 'Minimal',
                      description: nil, price: 0, item_group: nil,
                      variants: [], specs: [], stock_qty: 0)
      service = described_class.new(product: product)
      result = service.local_format
      expect(result).to include('Minimal')
      expect(result).to include('Stock: Out of stock')
      expect(result.split("\n").length).to eq(2)
    end
  end
end
