require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::Products#provision_tools', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:assistant) do
    create(:captain_assistant, account: account).tap do |a|
      a.config ||= {}
      a.erp_tenant_key = 'cs4uqhje2t'
      a.erp_company = 'Test Company'
      a.save!
    end
  end

  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('ERP_TENANT_SERVER_URL', nil).and_return('https://erp.example.com')
    allow(ENV).to receive(:fetch).with('ERP_TENANT_SERVER_API_KEY', nil).and_return('test-api-key')
  end

  describe 'POST /api/v1/accounts/:account_id/captain/assistants/:assistant_id/products/provision_tools' do
    let(:endpoint) do
      "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/products/provision_tools"
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post endpoint
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns unauthorized' do
        post endpoint, headers: agent.create_new_auth_token, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an admin with valid config' do
      it 'provisions tools and returns count' do
        post endpoint, headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response[:provisioned_count]).to eq(3)
        expect(json_response[:tools]).to be_an(Array)
        expect(json_response[:tools].size).to eq(3)
      end

      it 'creates custom tools in the database' do
        expect {
          post endpoint, headers: admin.create_new_auth_token, as: :json
        }.to change(Captain::CustomTool, :count).by(3)
      end

      it 'is idempotent — second call does not create duplicates' do
        post endpoint, headers: admin.create_new_auth_token, as: :json
        expect(response).to have_http_status(:ok)

        expect {
          post endpoint, headers: admin.create_new_auth_token, as: :json
        }.not_to change(Captain::CustomTool, :count)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when erp_tenant_key is not configured' do
      before do
        assistant.update!(config: assistant.config.except('erp_tenant_key'))
      end

      it 'returns unprocessable entity' do
        post endpoint, headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error]).to include('erp_tenant_key')
      end
    end
  end
end
