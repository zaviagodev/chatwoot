require 'rails_helper'

RSpec.describe Captain::Products::SyncService do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }

  describe '#sync' do
    it 'creates an AssistantResponse for the product' do
      product = create(:captain_product, assistant: assistant, account: account,
                                         formatted_text: "Jasmine Tea\nPrice: THB 120.00")
      service = described_class.new(product: product)

      expect { service.sync }.to change(Captain::AssistantResponse, :count).by(1)

      response = product.responses.first
      expect(response.answer).to eq("Jasmine Tea\nPrice: THB 120.00")
      expect(response.assistant).to eq(assistant)
      expect(response.account).to eq(account)
      expect(response.documentable).to eq(product)
      expect(response.status).to eq('approved')
    end

    it 'builds question from item_name, item_code, and item_group' do
      product = create(:captain_product, assistant: assistant, account: account,
                                         item_name: 'Jasmine Tea', item_code: 'TEA-001',
                                         item_group: 'Beverages',
                                         formatted_text: 'Some text')
      service = described_class.new(product: product)
      service.sync

      response = product.responses.first
      expect(response.question).to eq('Jasmine Tea - TEA-001 - Beverages')
    end

    it 'excludes item_code from question when same as item_name' do
      product = create(:captain_product, assistant: assistant, account: account,
                                         item_name: 'Jasmine Tea', item_code: 'Jasmine Tea',
                                         item_group: nil,
                                         formatted_text: 'Some text')
      service = described_class.new(product: product)
      service.sync

      response = product.responses.first
      expect(response.question).to eq('Jasmine Tea')
    end

    it 'updates existing response instead of creating duplicate' do
      product = create(:captain_product, assistant: assistant, account: account,
                                         formatted_text: 'Original text')
      service = described_class.new(product: product)
      service.sync

      product.update!(formatted_text: 'Updated text')
      expect { service.sync }.not_to change(Captain::AssistantResponse, :count)

      response = product.responses.first
      expect(response.answer).to eq('Updated text')
    end

    it 'sets documentable_type to Captain::Product' do
      product = create(:captain_product, assistant: assistant, account: account,
                                         formatted_text: 'Some text')
      service = described_class.new(product: product)
      service.sync

      response = product.responses.first
      expect(response.documentable_type).to eq('Captain::Product')
    end

    it 'skips sync when formatted_text is blank' do
      product = create(:captain_product, assistant: assistant, account: account,
                                         formatted_text: nil)
      service = described_class.new(product: product)
      expect { service.sync }.not_to change(Captain::AssistantResponse, :count)
    end
  end

  describe '#remove' do
    it 'destroys all associated responses' do
      product = create(:captain_product, assistant: assistant, account: account,
                                         formatted_text: 'Some text')
      service = described_class.new(product: product)
      service.sync

      expect(product.responses.count).to eq(1)
      expect { service.remove }.to change(Captain::AssistantResponse, :count).by(-1)
      expect(product.responses.count).to eq(0)
    end
  end
end
