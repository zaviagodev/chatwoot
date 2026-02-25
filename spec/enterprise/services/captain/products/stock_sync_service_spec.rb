require 'rails_helper'

RSpec.describe Captain::Products::StockSyncService do
  let(:account) { create(:account) }
  let(:assistant) do
    create(:captain_assistant, account: account).tap do |a|
      a.config ||= {}
      a.erp_tenant_key = 'test-tenant'
      a.erp_company = 'Test Company'
      a.erp_warehouse = 'Main Warehouse'
      a.save!
    end
  end

  let(:service) { described_class.new(assistant: assistant) }

  before do
    allow(ENV).to receive(:fetch).with('ERP_TENANT_SERVER_URL').and_return('https://erp.example.com')
    allow(ENV).to receive(:fetch).with('ERP_TENANT_SERVER_API_KEY').and_return('test-api-key')
  end

  describe '#sync' do
    context 'when assistant has no products' do
      it 'returns early with synced_count 0' do
        result = service.sync
        expect(result[:synced_count]).to eq(0)
      end
    end

    context 'when assistant has products' do
      let!(:product1) do
        create(:captain_product, assistant: assistant, account: account,
                                 item_code: 'ITEM-001', stock_qty: 10)
      end
      let!(:product2) do
        create(:captain_product, assistant: assistant, account: account,
                                 item_code: 'ITEM-002', stock_qty: 5)
      end

      before do
        stub_request(:post, 'https://erp.example.com/api/method/zaviago_backend.api.captain_tools.get_stock_batch')
          .to_return(
            status: 200,
            body: { message: { data: [{ item_code: 'ITEM-001', qty: 20, in_stock: true }, { item_code: 'ITEM-002', qty: 0, in_stock: false }] } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Stub the ManageService to avoid full format/sync pipeline
        manage_service = instance_double(Captain::Products::ManageService)
        allow(Captain::Products::ManageService).to receive(:new).and_return(manage_service)
        allow(manage_service).to receive(:update_stock).and_return(true)
      end

      it 'updates products where stock changed' do
        result = service.sync
        expect(result[:synced_count]).to eq(2)
      end

      it 'updates last_synced_at' do
        service.sync
        assistant.reload
        expect(assistant.last_synced_at).to be_present
      end

      it 'resets sync_error_count on success' do
        assistant.update!(config: assistant.config.merge('sync_error_count' => 3))
        service.sync
        assistant.reload
        expect(assistant.sync_error_count.to_i).to eq(0)
      end

      it 'does not update products where stock is unchanged' do
        product1.update!(stock_qty: 20) # Already matches API response
        manage_service = instance_double(Captain::Products::ManageService)
        allow(Captain::Products::ManageService).to receive(:new).and_return(manage_service)
        allow(manage_service).to receive(:update_stock)

        service.sync

        # Only product2 should be updated (0 != 5)
        expect(manage_service).to have_received(:update_stock).once
      end
    end

    context 'when ERPNext API fails' do
      let!(:product) do
        create(:captain_product, assistant: assistant, account: account,
                                 item_code: 'ITEM-001', stock_qty: 10)
      end

      before do
        stub_request(:post, 'https://erp.example.com/api/method/zaviago_backend.api.captain_tools.get_stock_batch')
          .to_return(status: 503, body: 'Service Unavailable')
      end

      it 'preserves existing stock data' do
        service.sync
        product.reload
        expect(product.stock_qty.to_f).to eq(10.0)
      end

      it 'increments sync_error_count' do
        result = service.sync
        assistant.reload
        expect(assistant.sync_error_count.to_i).to eq(1)
        expect(result[:error]).to be_present
      end
    end

    context 'when individual product update fails' do
      let!(:product1) do
        create(:captain_product, assistant: assistant, account: account,
                                 item_code: 'ITEM-001', stock_qty: 10)
      end
      let!(:product2) do
        create(:captain_product, assistant: assistant, account: account,
                                 item_code: 'ITEM-002', stock_qty: 5)
      end

      before do
        stub_request(:post, 'https://erp.example.com/api/method/zaviago_backend.api.captain_tools.get_stock_batch')
          .to_return(
            status: 200,
            body: { message: { data: [{ item_code: 'ITEM-001', qty: 20, in_stock: true }, { item_code: 'ITEM-002', qty: 0, in_stock: false }] } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        manage_service = instance_double(Captain::Products::ManageService)
        allow(Captain::Products::ManageService).to receive(:new).and_return(manage_service)
        call_count = 0
        allow(manage_service).to receive(:update_stock) do
          call_count += 1
          raise StandardError, 'DB error' if call_count == 1

          true
        end
      end

      it 'continues with remaining products after individual failure' do
        result = service.sync
        # One failed, one succeeded
        expect(result[:synced_count]).to eq(1)
      end
    end
  end
end
