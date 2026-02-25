require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::Products', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:assistant) do
    create(:captain_assistant, account: account).tap do |a|
      a.config ||= {}
      a.erp_company = 'Test Company'
      a.erp_warehouse = 'Main Warehouse'
      a.save!
    end
  end

  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  describe 'POST /api/v1/accounts/:account_id/captain/assistants/:assistant_id/products/sync' do
    let!(:product) do
      create(:captain_product, assistant: assistant, account: account,
                               item_code: 'ITEM-001', stock_qty: 10)
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/products/sync"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an admin' do
      before do
        sync_service = instance_double(Captain::Products::StockSyncService)
        allow(Captain::Products::StockSyncService).to receive(:new)
          .with(assistant: assistant)
          .and_return(sync_service)
        allow(sync_service).to receive(:sync).and_return({ synced_count: 1, last_synced_at: Time.current.iso8601 })
      end

      it 'triggers stock sync and returns result' do
        post "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/products/sync",
             headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response[:synced_count]).to eq(1)
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/captain/assistants/:assistant_id/products/sync_status' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/products/sync_status"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an admin' do
      before do
        assistant.update!(config: assistant.config.merge(
                            'last_synced_at' => '2026-02-24T10:00:00Z',
                            'sync_error_count' => 2,
                            'sync_interval' => 1800
                          ))
      end

      it 'returns sync status fields' do
        get "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/products/sync_status",
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response[:last_synced_at]).to eq('2026-02-24T10:00:00Z')
        expect(json_response[:sync_error_count]).to eq(2)
        expect(json_response[:sync_interval]).to eq(1800)
      end
    end

    context 'when sync has never run' do
      it 'returns defaults' do
        get "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/products/sync_status",
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response[:last_synced_at]).to be_nil
        expect(json_response[:sync_error_count]).to eq(0)
        expect(json_response[:sync_interval]).to eq(3600)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/captain/assistants/:assistant_id/products/:id/enrich' do
    let!(:product) do
      create(:captain_product, assistant: assistant, account: account,
                               item_code: 'ITEM-001', item_name: 'Test Product',
                               price: 50.0, currency: 'USD', stock_qty: 10)
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/products/#{product.id}/enrich"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an admin and enrichment succeeds' do
      before do
        enrich_service = instance_double(Captain::Products::AiEnrichService)
        allow(Captain::Products::AiEnrichService).to receive(:new)
          .with(product: product)
          .and_return(enrich_service)
        allow(enrich_service).to receive(:enrich).and_return({
                                                               enriched_text: 'AI-generated description for this product.',
                                                               input_tokens: 100,
                                                               output_tokens: 50
                                                             })
      end

      it 'returns enriched text' do
        post "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/products/#{product.id}/enrich",
             headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response[:enriched_text]).to eq('AI-generated description for this product.')
      end
    end

    context 'when enrichment fails' do
      before do
        enrich_service = instance_double(Captain::Products::AiEnrichService)
        allow(Captain::Products::AiEnrichService).to receive(:new)
          .with(product: product)
          .and_return(enrich_service)
        allow(enrich_service).to receive(:enrich).and_return({ error: 'LLM unavailable' })
      end

      it 'returns unprocessable entity with error' do
        post "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/products/#{product.id}/enrich",
             headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error]).to eq('LLM unavailable')
      end
    end
  end

  describe 'PUT /api/v1/accounts/:account_id/captain/assistants/:assistant_id/products/:id/approve_enrichment' do
    let!(:product) do
      create(:captain_product, assistant: assistant, account: account,
                               item_code: 'ITEM-001', item_name: 'Test Product',
                               formatted_text: 'Old description')
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/products/#{product.id}/approve_enrichment"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an admin with valid text' do
      before do
        manage_service = instance_double(Captain::Products::ManageService)
        allow(Captain::Products::ManageService).to receive(:new)
          .with(assistant: assistant, account: account)
          .and_return(manage_service)

        updated_product = product.tap do |p|
          p.description_source = 'ai'
          p.formatted_text = 'AI-approved description'
        end
        allow(manage_service).to receive(:update_description).and_return(updated_product)
      end

      it 'approves the enrichment and returns full product' do
        put "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/products/#{product.id}/approve_enrichment",
            params: { text: 'AI-approved description' },
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response[:id]).to eq(product.id)
        expect(json_response[:description_source]).to eq('ai')
        expect(json_response[:item_code]).to eq(product.item_code)
      end
    end

    context 'when text is missing' do
      it 'returns unprocessable entity' do
        put "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/products/#{product.id}/approve_enrichment",
            params: {},
            headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error]).to eq('text is required')
      end
    end
  end
end
