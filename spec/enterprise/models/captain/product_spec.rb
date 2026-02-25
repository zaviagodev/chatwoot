require 'rails_helper'

RSpec.describe Captain::Product, type: :model do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }

  describe 'validations' do
    it 'requires item_code' do
      product = build(:captain_product, assistant: assistant, account: account, item_code: nil)
      expect(product).not_to be_valid
      expect(product.errors[:item_code]).to include("can't be blank")
    end

    it 'requires item_name' do
      product = build(:captain_product, assistant: assistant, account: account, item_name: nil)
      expect(product).not_to be_valid
      expect(product.errors[:item_name]).to include("can't be blank")
    end

    it 'enforces description_source inclusion' do
      product = build(:captain_product, assistant: assistant, account: account, description_source: 'invalid')
      expect(product).not_to be_valid
      expect(product.errors[:description_source]).to be_present
    end

    it 'accepts valid description_source values' do
      %w[auto ai manual].each do |source|
        product = build(:captain_product, assistant: assistant, account: account, description_source: source)
        expect(product).to be_valid
      end
    end

    it 'enforces uniqueness of item_code per assistant' do
      create(:captain_product, assistant: assistant, account: account, item_code: 'DUP-001')
      duplicate = build(:captain_product, assistant: assistant, account: account, item_code: 'DUP-001')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:item_code]).to include('already exists for this assistant')
    end

    it 'allows same item_code on different assistants' do
      other_assistant = create(:captain_assistant, account: account)
      create(:captain_product, assistant: assistant, account: account, item_code: 'SHARED-001')
      product = build(:captain_product, assistant: other_assistant, account: account, item_code: 'SHARED-001')
      expect(product).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to account' do
      product = create(:captain_product, assistant: assistant, account: account)
      expect(product.account).to eq(account)
    end

    it 'belongs to assistant' do
      product = create(:captain_product, assistant: assistant, account: account)
      expect(product.assistant).to eq(assistant)
    end

    it 'has many responses as documentable' do
      product = create(:captain_product, assistant: assistant, account: account)
      response = create(:captain_assistant_response,
                        assistant: assistant,
                        account: account,
                        documentable: product)
      expect(product.responses).to include(response)
    end

    it 'destroys responses when destroyed' do
      product = create(:captain_product, assistant: assistant, account: account)
      create(:captain_assistant_response,
             assistant: assistant,
             account: account,
             documentable: product)
      expect { product.destroy! }.to change(Captain::AssistantResponse, :count).by(-1)
    end
  end

  describe 'scopes' do
    it '.ordered returns newest first' do
      old_product = create(:captain_product, assistant: assistant, account: account,
                                             item_code: 'OLD-001', created_at: 1.day.ago)
      new_product = create(:captain_product, assistant: assistant, account: account,
                                             item_code: 'NEW-001', created_at: Time.current)
      expect(described_class.ordered).to eq([new_product, old_product])
    end

    it '.for_account filters by account_id' do
      other_account = create(:account)
      other_assistant = create(:captain_assistant, account: other_account)
      product = create(:captain_product, assistant: assistant, account: account)
      create(:captain_product, assistant: other_assistant, account: other_account)
      expect(described_class.for_account(account.id)).to eq([product])
    end

    it '.for_assistant filters by assistant_id' do
      other_assistant = create(:captain_assistant, account: account)
      product = create(:captain_product, assistant: assistant, account: account)
      create(:captain_product, assistant: other_assistant, account: account)
      expect(described_class.for_assistant(assistant.id)).to eq([product])
    end

    it '.in_stock returns only in-stock products' do
      in_stock = create(:captain_product, assistant: assistant, account: account,
                                          item_code: 'IN-001', stock_status: 'in_stock')
      create(:captain_product, :out_of_stock, assistant: assistant, account: account,
                                              item_code: 'OUT-001')
      expect(described_class.in_stock).to eq([in_stock])
    end
  end

  describe '#in_stock?' do
    it 'returns true when stock_qty is positive' do
      product = build(:captain_product, stock_qty: 10)
      expect(product.in_stock?).to be true
    end

    it 'returns false when stock_qty is zero' do
      product = build(:captain_product, stock_qty: 0)
      expect(product.in_stock?).to be false
    end

    it 'returns false when stock_qty is nil' do
      product = build(:captain_product, stock_qty: nil)
      expect(product.in_stock?).to be false
    end
  end

  describe '#update_stock' do
    it 'updates stock_qty and stock_status to in_stock' do
      product = create(:captain_product, :out_of_stock, assistant: assistant, account: account)
      product.update_stock(25)
      expect(product.reload.stock_qty).to eq(25)
      expect(product.stock_status).to eq('in_stock')
    end

    it 'updates stock_qty and stock_status to out_of_stock' do
      product = create(:captain_product, assistant: assistant, account: account, stock_qty: 50)
      product.update_stock(0)
      expect(product.reload.stock_qty).to eq(0)
      expect(product.stock_status).to eq('out_of_stock')
    end
  end
end
