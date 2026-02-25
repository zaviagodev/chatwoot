require 'rails_helper'

RSpec.describe Captain::Products::ManageService do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:service) { described_class.new(assistant: assistant, account: account) }

  describe '#create' do
    let(:product_data) do
      {
        item_code: 'TEA-001',
        item_name: 'Jasmine Tea',
        description: 'Premium jasmine green tea',
        price: 120.00,
        currency: 'THB',
        stock_qty: 50,
        item_group: 'Beverages',
        image: 'https://example.com/tea.jpg',
        variants: [{ 'item_code' => 'TEA-001-S', 'item_name' => 'Small' }],
        specs: [{ 'label' => 'Weight', 'value' => '100g' }],
        formatted_text: "Jasmine Tea\nCategory: Beverages\nPrice: THB 120.00\nStock: In stock (50 available)"
      }
    end

    it 'creates a product with all fields' do
      product = service.create(product_data)
      expect(product).to be_persisted
      expect(product.item_code).to eq('TEA-001')
      expect(product.item_name).to eq('Jasmine Tea')
      expect(product.price).to eq(120.00)
      expect(product.stock_qty).to eq(50)
      expect(product.stock_status).to eq('in_stock')
      expect(product.description_source).to eq('auto')
      expect(product.variants).to eq([{ 'item_code' => 'TEA-001-S', 'item_name' => 'Small' }])
    end

    it 'uses formatted_text from API response' do
      product = service.create(product_data)
      expect(product.formatted_text).to include('Jasmine Tea')
      expect(product.formatted_text).to include('Price: THB 120.00')
    end

    it 'falls back to local format when no formatted_text provided' do
      data = product_data.except(:formatted_text)
      product = service.create(data)
      expect(product.formatted_text).to include('Jasmine Tea')
      expect(product.formatted_text).to include('Stock: In stock')
    end

    it 'creates an AssistantResponse via sync' do
      expect { service.create(product_data) }.to change(Captain::AssistantResponse, :count).by(1)
    end

    it 'sets default stock_qty to 0 when nil' do
      data = product_data.merge(stock_qty: nil)
      product = service.create(data)
      expect(product.stock_qty).to eq(0)
      expect(product.stock_status).to eq('unknown')
    end
  end

  describe '#update' do
    let!(:product) { create(:captain_product, assistant: assistant, account: account, item_code: 'UPD-001') }

    it 'updates product fields' do
      service.update(product, { item_name: 'Updated Name', formatted_text: 'Updated text' })
      expect(product.reload.item_name).to eq('Updated Name')
    end

    it 're-syncs the knowledge base' do
      # First create a response
      Captain::Products::SyncService.new(product: product).sync
      expect(product.responses.count).to eq(1)

      service.update(product, { formatted_text: 'Brand new text' })
      expect(product.responses.first.answer).to eq('Brand new text')
    end

    it 'resets description_source when reset_source is true' do
      product.update!(description_source: 'manual')
      service.update(product, { formatted_text: 'Reset text' }, reset_source: true)
      expect(product.reload.description_source).to eq('auto')
    end

    it 'preserves existing values when keys are absent from product_data' do
      original_name = product.item_name
      service.update(product, { formatted_text: 'New text' })
      expect(product.reload.item_name).to eq(original_name)
    end

    it 'handles falsy values correctly (price=0)' do
      service.update(product, { price: 0, formatted_text: 'Free product' })
      expect(product.reload.price).to eq(0)
    end
  end

  describe '#update_stock' do
    let!(:product) { create(:captain_product, assistant: assistant, account: account, stock_qty: 100) }

    it 'updates stock_qty and stock_status' do
      service.update_stock(product, 25)
      expect(product.reload.stock_qty).to eq(25)
      expect(product.stock_status).to eq('in_stock')
    end

    it 'sets out_of_stock when qty is 0' do
      service.update_stock(product, 0)
      expect(product.reload.stock_qty).to eq(0)
      expect(product.stock_status).to eq('out_of_stock')
    end

    it 're-formats locally and syncs' do
      Captain::Products::SyncService.new(product: product).sync
      service.update_stock(product, 10)
      response = product.responses.first
      expect(response.answer).to include('Stock: In stock (10 available)')
    end
  end

  describe '#update_description' do
    let!(:product) { create(:captain_product, assistant: assistant, account: account) }

    it 'updates formatted_text and description_source' do
      service.update_description(product, text: 'Custom description', source: 'manual')
      expect(product.reload.formatted_text).to eq('Custom description')
      expect(product.description_source).to eq('manual')
    end

    it 'syncs the new description to knowledge base' do
      Captain::Products::SyncService.new(product: product).sync
      service.update_description(product, text: 'AI-written text', source: 'ai')
      expect(product.responses.first.answer).to eq('AI-written text')
    end
  end

  describe '#destroy' do
    let!(:product) { create(:captain_product, assistant: assistant, account: account) }

    before do
      Captain::Products::SyncService.new(product: product).sync
    end

    it 'removes the product' do
      expect { service.destroy(product) }.to change(Captain::Product, :count).by(-1)
    end

    it 'removes associated AssistantResponse' do
      expect { service.destroy(product) }.to change(Captain::AssistantResponse, :count).by(-1)
    end
  end
end
