require 'rails_helper'

RSpec.describe Captain::Products::AiEnrichService do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:product) do
    create(:captain_product, assistant: assistant, account: account,
                             item_code: 'ITEM-001', item_name: 'Wireless Headphones',
                             description: 'Over-ear wireless headphones with noise cancellation',
                             price: 99.99, currency: 'USD', stock_qty: 50,
                             item_group: 'Electronics')
  end

  let(:service) { described_class.new(product: product) }
  let(:mock_chat) { instance_double(RubyLLM::Chat) }
  let(:mock_response) do
    instance_double(RubyLLM::Message, content: 'These wireless headphones offer great sound quality with active noise cancellation.')
  end

  before do
    create(:installation_config, name: 'CAPTAIN_OPEN_AI_API_KEY', value: 'test-key')
    allow(RubyLLM).to receive(:chat).and_return(mock_chat)
    allow(mock_chat).to receive(:with_temperature).and_return(mock_chat)
    allow(mock_chat).to receive(:with_instructions).and_return(mock_chat)
    allow(mock_chat).to receive(:ask).and_return(mock_response)
  end

  describe '#enrich' do
    context 'when successful' do
      it 'returns enriched text' do
        result = service.enrich
        expect(result[:enriched_text]).to eq('These wireless headphones offer great sound quality with active noise cancellation.')
      end

      it 'returns token usage when available' do
        Thread.current[:captain_llm_usage] = { input_tokens: 100, output_tokens: 50 }
        result = service.enrich
        expect(result[:input_tokens]).to eq(100)
        expect(result[:output_tokens]).to eq(50)
      ensure
        Thread.current[:captain_llm_usage] = nil
      end

      it 'builds context including product details' do
        expect(mock_chat).to receive(:ask) do |context|
          expect(context).to include('Wireless Headphones')
          expect(context).to include('Electronics')
          expect(context).to include('USD 99.99')
          expect(context).to include('In stock (50 units)')
          mock_response
        end

        service.enrich
      end

      it 'uses the system prompt for product copywriting' do
        expect(mock_chat).to receive(:with_instructions) do |prompt|
          expect(prompt).to include('product copywriter')
          expect(prompt).to include('Keep under 150 words')
          mock_chat
        end

        service.enrich
      end
    end

    context 'when product has no price' do
      let(:product) do
        create(:captain_product, assistant: assistant, account: account,
                                 item_code: 'ITEM-002', item_name: 'Free Sample',
                                 price: 0, stock_qty: 10)
      end

      it 'omits price from context' do
        expect(mock_chat).to receive(:ask) do |context|
          expect(context).not_to include('Price:')
          mock_response
        end

        service.enrich
      end
    end

    context 'when product is out of stock' do
      let(:product) do
        create(:captain_product, assistant: assistant, account: account,
                                 item_code: 'ITEM-003', item_name: 'Sold Out Item',
                                 price: 25.0, currency: 'USD', stock_qty: 0)
      end

      it 'includes out of stock in context' do
        expect(mock_chat).to receive(:ask) do |context|
          expect(context).to include('Out of stock')
          mock_response
        end

        service.enrich
      end
    end

    context 'when LLM returns nil content' do
      let(:nil_response) { instance_double(RubyLLM::Message, content: nil) }

      before do
        allow(mock_chat).to receive(:ask).and_return(nil_response)
      end

      it 'returns nil enriched_text' do
        result = service.enrich
        expect(result[:enriched_text]).to be_nil
      end
    end

    context 'when LLM raises an error' do
      before do
        allow(mock_chat).to receive(:ask).and_raise(RubyLLM::Error.new(nil, 'Rate limit exceeded'))
      end

      it 'returns error hash' do
        result = service.enrich
        expect(result[:error]).to eq('Rate limit exceeded')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/LLM error for product ITEM-001/)
        service.enrich
      end
    end
  end
end
