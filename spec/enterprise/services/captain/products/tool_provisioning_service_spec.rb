require 'rails_helper'

RSpec.describe Captain::Products::ToolProvisioningService do
  let(:account) { create(:account) }
  let(:assistant) do
    create(:captain_assistant, account: account).tap do |a|
      a.config ||= {}
      a.erp_tenant_key = 'cs4uqhje2t'
      a.erp_company = 'Test Company'
      a.save!
    end
  end

  let(:service) { described_class.new(assistant: assistant) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('ERP_TENANT_SERVER_URL', nil).and_return('https://erp.example.com')
    allow(ENV).to receive(:fetch).with('ERP_TENANT_SERVER_API_KEY', nil).and_return('test-api-key-123')
  end

  describe '#provision_tools' do
    it 'creates 3 custom tools' do
      expect { service.provision_tools }.to change(Captain::CustomTool, :count).by(3)
    end

    it 'returns provisioned_count and tool metadata' do
      result = service.provision_tools
      expect(result[:provisioned_count]).to eq(3)
      expect(result[:tools].map { |t| t[:id] }).to contain_exactly(
        'custom_order_status', 'custom_stock_check', 'custom_customer_account'
      )
    end

    it 'creates tools with correct slugs' do
      service.provision_tools
      slugs = account.captain_custom_tools.pluck(:slug)
      expect(slugs).to contain_exactly('custom_order_status', 'custom_stock_check', 'custom_customer_account')
    end

    it 'creates tools on the account (not assistant-scoped)' do
      service.provision_tools
      expect(account.captain_custom_tools.count).to eq(3)
    end

    it 'sets correct auth config on all tools' do
      service.provision_tools
      account.captain_custom_tools.each do |tool|
        expect(tool.auth_type).to eq('api_key')
        expect(tool.auth_config['key']).to eq('test-api-key-123')
        expect(tool.auth_config['location']).to eq('header')
        expect(tool.auth_config['name']).to eq('X-API-Key')
      end
    end

    it 'sets all tools as enabled' do
      service.provision_tools
      expect(account.captain_custom_tools.enabled.count).to eq(3)
    end

    it 'sets http_method to POST on all tools' do
      service.provision_tools
      expect(account.captain_custom_tools.pluck(:http_method).uniq).to eq(['POST'])
    end

    it 'bakes tenant_key as literal value in request templates' do
      service.provision_tools
      account.captain_custom_tools.each do |tool|
        expect(tool.request_template).to include('"tenant_key": "cs4uqhje2t"')
        expect(tool.request_template).not_to include('{{ tenant_key }}')
      end
    end

    it 'creates a Product Support scenario' do
      expect { service.provision_tools }.to change(Captain::Scenario, :count).by(1)
      scenario = assistant.scenarios.find_by(title: 'Product Support')
      expect(scenario).to be_present
      expect(scenario.enabled).to be(true)
    end

    it 'creates scenario with tool references in instruction' do
      service.provision_tools
      scenario = assistant.scenarios.find_by(title: 'Product Support')
      expect(scenario.instruction).to include('tool://custom_order_status')
      expect(scenario.instruction).to include('tool://custom_stock_check')
      expect(scenario.instruction).to include('tool://custom_customer_account')
    end

    it 'populates scenario tools JSONB via resolve_tool_references' do
      service.provision_tools
      scenario = assistant.scenarios.find_by(title: 'Product Support')
      expect(scenario.tools).to contain_exactly('custom_order_status', 'custom_stock_check', 'custom_customer_account')
    end

    context 'idempotency' do
      it 'does not create duplicate tools when run twice' do
        service.provision_tools
        expect { service.provision_tools }.not_to change(Captain::CustomTool, :count)
      end

      it 'does not create duplicate scenarios when run twice' do
        service.provision_tools
        expect { service.provision_tools }.not_to change(Captain::Scenario, :count)
      end

      it 'returns same result on second run' do
        first = service.provision_tools
        second = service.provision_tools
        expect(second[:provisioned_count]).to eq(first[:provisioned_count])
      end
    end

    context 'when erp_tenant_key is not configured' do
      before do
        assistant.update!(config: assistant.config.except('erp_tenant_key'))
      end

      it 'raises ArgumentError' do
        expect { service.provision_tools }.to raise_error(ArgumentError, /erp_tenant_key/)
      end
    end

    context 'when ERP_TENANT_SERVER_URL is missing' do
      before do
        allow(ENV).to receive(:fetch).with('ERP_TENANT_SERVER_URL', nil).and_return(nil)
      end

      it 'raises ArgumentError' do
        expect { service.provision_tools }.to raise_error(ArgumentError, /ERP_TENANT_SERVER_URL/)
      end
    end

    context 'when ERP_TENANT_SERVER_API_KEY is missing' do
      before do
        allow(ENV).to receive(:fetch).with('ERP_TENANT_SERVER_API_KEY', nil).and_return(nil)
      end

      it 'raises ArgumentError' do
        expect { service.provision_tools }.to raise_error(ArgumentError, /ERP_TENANT_SERVER_API_KEY/)
      end
    end
  end

  describe '#deprovision_tools' do
    before { service.provision_tools }

    it 'removes all provisioned tools' do
      expect { service.deprovision_tools }.to change(Captain::CustomTool, :count).by(-3)
    end

    it 'removes the Product Support scenario' do
      expect { service.deprovision_tools }.to change(Captain::Scenario, :count).by(-1)
    end

    it 'does not remove other custom tools' do
      create(:captain_custom_tool, account: account, slug: 'custom_other_tool')
      expect { service.deprovision_tools }.to change(Captain::CustomTool, :count).by(-3)
      expect(account.captain_custom_tools.find_by(slug: 'custom_other_tool')).to be_present
    end
  end
end
