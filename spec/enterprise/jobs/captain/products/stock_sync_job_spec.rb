require 'rails_helper'

RSpec.describe Captain::Products::StockSyncJob do
  let(:account) { create(:account) }
  let(:assistant) do
    create(:captain_assistant, account: account).tap do |a|
      a.config ||= {}
      a.erp_company = 'Test Company'
      a.erp_warehouse = 'Main Warehouse'
      a.save!
    end
  end

  describe '#perform' do
    context 'when no assistants have products' do
      it 'completes without errors' do
        expect { described_class.perform_now }.not_to raise_error
      end
    end

    context 'when assistant has products and sync is due' do
      let!(:product) do
        create(:captain_product, assistant: assistant, account: account,
                                 item_code: 'ITEM-001', stock_qty: 10)
      end

      before do
        # Ensure sync is due (no last_synced_at = always due)
        sync_service = instance_double(Captain::Products::StockSyncService)
        allow(Captain::Products::StockSyncService).to receive(:new)
          .with(assistant: assistant)
          .and_return(sync_service)
        allow(sync_service).to receive(:sync).and_return({ synced_count: 1 })
      end

      it 'calls StockSyncService for the assistant' do
        described_class.perform_now
        expect(Captain::Products::StockSyncService).to have_received(:new).with(assistant: assistant)
      end
    end

    context 'when sync is not yet due' do
      let!(:product) do
        create(:captain_product, assistant: assistant, account: account,
                                 item_code: 'ITEM-001', stock_qty: 10)
      end

      before do
        assistant.update!(config: assistant.config.merge(
                            'last_synced_at' => Time.current.iso8601,
                            'sync_interval' => 3600
                          ))
      end

      it 'skips the assistant' do
        expect(Captain::Products::StockSyncService).not_to receive(:new)
        described_class.perform_now
      end
    end

    context 'when one assistant fails' do
      let(:assistant2) do
        create(:captain_assistant, account: account).tap do |a|
          a.config ||= {}
          a.erp_company = 'Company 2'
          a.erp_warehouse = 'Warehouse 2'
          a.save!
        end
      end

      let!(:product1) do
        create(:captain_product, assistant: assistant, account: account,
                                 item_code: 'ITEM-001', stock_qty: 10)
      end
      let!(:product2) do
        create(:captain_product, assistant: assistant2, account: account,
                                 item_code: 'ITEM-002', stock_qty: 5)
      end

      before do
        sync_service1 = instance_double(Captain::Products::StockSyncService)
        sync_service2 = instance_double(Captain::Products::StockSyncService)

        allow(Captain::Products::StockSyncService).to receive(:new) do |args|
          if args[:assistant] == assistant
            sync_service1
          else
            sync_service2
          end
        end

        allow(sync_service1).to receive(:sync).and_raise(StandardError, 'Connection timeout')
        allow(sync_service2).to receive(:sync).and_return({ synced_count: 1 })
      end

      it 'continues processing other assistants' do
        expect { described_class.perform_now }.not_to raise_error
      end
    end

    context 'when last_synced_at has invalid format' do
      let!(:product) do
        create(:captain_product, assistant: assistant, account: account,
                                 item_code: 'ITEM-001', stock_qty: 10)
      end

      before do
        assistant.update!(config: assistant.config.merge('last_synced_at' => 'not-a-date'))

        sync_service = instance_double(Captain::Products::StockSyncService)
        allow(Captain::Products::StockSyncService).to receive(:new).and_return(sync_service)
        allow(sync_service).to receive(:sync).and_return({ synced_count: 0 })
      end

      it 'treats invalid date as epoch (sync is due)' do
        described_class.perform_now
        expect(Captain::Products::StockSyncService).to have_received(:new)
      end
    end
  end
end
