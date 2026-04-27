require 'rails_helper'

RSpec.describe Captain::Erp::ApiClient do
  let(:account) { create(:account) }
  let(:assistant) do
    create(:captain_assistant, account: account).tap do |a|
      a.config ||= {}
      a.erp_tenant_key = 'test-tenant-key'
      a.erp_company = 'Test Company'
      a.save!
    end
  end

  before do
    allow(ENV).to receive(:fetch).with('ERP_TENANT_SERVER_URL').and_return('https://erp.example.com')
    allow(ENV).to receive(:fetch).with('ERP_TENANT_SERVER_API_KEY').and_return('test-api-key')
  end

  let(:client) { described_class.new(assistant: assistant) }

  describe '#search_products' do
    it 'calls the correct endpoint with company and query params' do
      stub_request(:post, 'https://erp.example.com/api/method/zaviago_backend.api.captain_tools.search_products')
        .with(
          body: { tenant_key: 'test-tenant-key', query: 'tea', limit: 20, start: 0 }.to_json,
          headers: { 'Content-Type' => 'application/json', 'X-API-Key' => 'test-api-key' }
        )
        .to_return(
          status: 200,
          body: { message: { products: [{ item_code: 'TEA-001', item_name: 'Jasmine Tea' }] } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.search_products(query: 'tea')
      expect(result).to eq({ 'products' => [{ 'item_code' => 'TEA-001', 'item_name' => 'Jasmine Tea' }] })
    end

    it 'returns error hash on timeout' do
      stub_request(:post, 'https://erp.example.com/api/method/zaviago_backend.api.captain_tools.search_products')
        .to_timeout

      result = client.search_products(query: 'tea')
      expect(result[:error]).to include('Workspace connection timed out')
      expect(result[:status]).to eq(503)
    end

    it 'returns error hash on connection refused' do
      stub_request(:post, 'https://erp.example.com/api/method/zaviago_backend.api.captain_tools.search_products')
        .to_raise(Errno::ECONNREFUSED)

      result = client.search_products(query: 'tea')
      expect(result[:error]).to include('Workspace connection timed out')
      expect(result[:status]).to eq(503)
    end

    it 'returns error on non-success response' do
      stub_request(:post, 'https://erp.example.com/api/method/zaviago_backend.api.captain_tools.search_products')
        .to_return(status: 500, body: 'Internal Server Error')

      result = client.search_products(query: 'tea')
      expect(result[:error]).to eq('Request failed. Please try again.')
      expect(result[:status]).to eq(500)
    end
  end

  describe '#get_item_groups' do
    it 'calls the correct endpoint' do
      stub_request(:post, 'https://erp.example.com/api/method/zaviago_backend.api.captain_tools.get_item_groups')
        .to_return(
          status: 200,
          body: { message: { item_groups: [{ name: 'Beverages' }] } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.get_item_groups
      expect(result).to eq({ 'item_groups' => [{ 'name' => 'Beverages' }] })
    end
  end

  describe '#get_warehouses' do
    it 'calls the correct endpoint' do
      stub_request(:post, 'https://erp.example.com/api/method/zaviago_backend.api.captain_tools.get_warehouses')
        .to_return(
          status: 200,
          body: { message: { warehouses: [{ name: 'Main Warehouse' }] } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.get_warehouses
      expect(result).to eq({ 'warehouses' => [{ 'name' => 'Main Warehouse' }] })
    end
  end

  describe '#get_product_detail' do
    it 'calls the correct endpoint with item_code' do
      stub_request(:post, 'https://erp.example.com/api/method/zaviago_backend.api.captain_tools.get_product_detail')
        .with(
          body: { tenant_key: 'test-tenant-key', item_code: 'TEA-001' }.to_json
        )
        .to_return(
          status: 200,
          body: { message: { item_code: 'TEA-001', item_name: 'Jasmine Tea', price: 120 } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.get_product_detail(item_code: 'TEA-001')
      expect(result['item_code']).to eq('TEA-001')
    end
  end

  describe '#create_shared_checkout' do
    let(:checkout_url) { 'https://erp.example.com/api/method/zaviago_backend.storefront.shared_checkout.create_shared_checkout' }

    before { allow(client).to receive(:sleep) }

    it 'returns checkout data on success' do
      stub_request(:post, checkout_url)
        .to_return(
          status: 200,
          body: { message: { checkout_url: 'https://shop.example.com/checkout/abc' } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.create_shared_checkout(items: [{ item_code: 'TEA-001', qty: 1 }].to_json)
      expect(result['checkout_url']).to eq('https://shop.example.com/checkout/abc')
    end

    it 'retries once on 502 and succeeds' do
      stub_request(:post, checkout_url)
        .to_return(
          { status: 502, body: 'Bad Gateway' },
          { status: 200, body: { message: { checkout_url: 'https://shop.example.com/checkout/abc' } }.to_json,
            headers: { 'Content-Type' => 'application/json' } }
        )

      result = client.create_shared_checkout(items: [{ item_code: 'TEA-001', qty: 1 }].to_json)
      expect(result['checkout_url']).to eq('https://shop.example.com/checkout/abc')
    end

    it 'returns error after retry exhausted on 503' do
      stub_request(:post, checkout_url)
        .to_return(status: 503, body: 'Service Unavailable')

      result = client.create_shared_checkout(items: [{ item_code: 'TEA-001', qty: 1 }].to_json)
      expect(result[:error]).to eq('Request failed. Please try again.')
      expect(result[:status]).to eq(503)
    end

    it 'retries once on timeout and succeeds' do
      call_count = 0
      stub_request(:post, checkout_url).to_return do
        call_count += 1
        if call_count == 1
          raise Net::ReadTimeout
        else
          { status: 200, body: { message: { checkout_url: 'https://shop.example.com/checkout/abc' } }.to_json,
            headers: { 'Content-Type' => 'application/json' } }
        end
      end

      result = client.create_shared_checkout(items: [{ item_code: 'TEA-001', qty: 1 }].to_json)
      expect(result['checkout_url']).to eq('https://shop.example.com/checkout/abc')
    end

    it 'returns error after retry exhausted on timeout' do
      stub_request(:post, checkout_url).to_timeout

      result = client.create_shared_checkout(items: [{ item_code: 'TEA-001', qty: 1 }].to_json)
      expect(result[:error]).to include('Workspace connection timed out')
      expect(result[:status]).to eq(503)
    end

    it 'does not retry on 417 validation error' do
      stub_request(:post, checkout_url)
        .to_return(status: 417, body: { _server_messages: ['{"message":"Item out of stock"}'].to_json }.to_json)

      result = client.create_shared_checkout(items: [{ item_code: 'TEA-001', qty: 1 }].to_json)
      expect(result[:error]).to eq('Item out of stock')
      expect(result[:status]).to eq(417)
    end
  end

  describe 'missing ENV configuration' do
    it 'raises KeyError when ERP_TENANT_SERVER_URL is not set' do
      allow(ENV).to receive(:fetch).with('ERP_TENANT_SERVER_URL').and_call_original
      ENV.delete('ERP_TENANT_SERVER_URL') if ENV.key?('ERP_TENANT_SERVER_URL')
      expect { described_class.new(assistant: assistant) }.to raise_error(KeyError)
    end
  end
end
