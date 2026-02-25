require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::ErpProxy', type: :request do
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

  let(:api_client_double) { instance_double(Captain::Erp::ApiClient) }

  before do
    allow(Captain::Erp::ApiClient).to receive(:new).and_return(api_client_double)
  end

  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  describe 'POST /api/v1/accounts/:account_id/captain/assistants/:assistant_id/erp_proxy/search_products' do
    let(:url) { "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/erp_proxy/search_products" }

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post url
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      it 'returns search results' do
        allow(api_client_double).to receive(:search_products).and_return(
          { 'products' => [{ 'item_code' => 'TEA-001', 'item_name' => 'Jasmine Tea' }] }
        )

        post url, params: { query: 'tea' }, headers: admin.create_new_auth_token, as: :json
        expect(response).to have_http_status(:ok)
        expect(json_response[:products]).to be_an(Array)
      end

      it 'forwards query and item_group params' do
        expect(api_client_double).to receive(:search_products).with(
          query: 'tea', item_group: 'Beverages', page: 1, page_size: 20
        )

        post url, params: { query: 'tea', item_group: 'Beverages' },
             headers: admin.create_new_auth_token, as: :json
      end

      it 'returns 502 on ERPNext error' do
        allow(api_client_double).to receive(:search_products).and_return(
          { error: 'ERPNext connection failed: Net::OpenTimeout', status: 503 }
        )

        post url, params: { query: 'tea' }, headers: admin.create_new_auth_token, as: :json
        expect(response).to have_http_status(:service_unavailable)
        expect(json_response[:error]).to include('ERPNext connection failed')
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/captain/assistants/:assistant_id/erp_proxy/item_groups' do
    let(:url) { "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/erp_proxy/item_groups" }

    context 'when authenticated as admin' do
      it 'returns item groups' do
        allow(api_client_double).to receive(:get_item_groups).and_return(
          { 'item_groups' => [{ 'name' => 'Beverages' }] }
        )

        get url, headers: admin.create_new_auth_token, as: :json
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/captain/assistants/:assistant_id/erp_proxy/warehouses' do
    let(:url) { "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/erp_proxy/warehouses" }

    context 'when authenticated as admin' do
      it 'returns warehouses' do
        allow(api_client_double).to receive(:get_warehouses).and_return(
          { 'warehouses' => [{ 'name' => 'Main Warehouse' }] }
        )

        get url, headers: admin.create_new_auth_token, as: :json
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/captain/assistants/:assistant_id/erp_proxy/setup' do
    let(:url) { "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/erp_proxy/setup" }

    context 'when authenticated as admin' do
      it 'saves erp_company to assistant config' do
        post url, params: { erp_company: 'New Company', erp_warehouse: 'Warehouse A' },
             headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:ok)
        assistant.reload
        expect(assistant.erp_company).to eq('New Company')
        expect(assistant.erp_warehouse).to eq('Warehouse A')
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post url, params: { erp_company: 'Test' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
