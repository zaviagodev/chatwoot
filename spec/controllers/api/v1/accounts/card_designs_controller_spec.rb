require 'rails_helper'

RSpec.describe 'Card Designs API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  let(:valid_design_json) do
    {
      'sections' => {
        'hero' => { 'enabled' => true, 'aspect_ratio' => '20:13' },
        'title' => { 'enabled' => true, 'size' => 'lg', 'weight' => 'bold' },
        'subtitle' => { 'enabled' => false, 'size' => 'md', 'color' => '#999999' },
        'price' => { 'enabled' => true, 'size' => 'md', 'color' => '#666666' },
        'button' => { 'enabled' => true, 'label' => 'View Product', 'style' => 'primary' }
      },
      'colors' => { 'background' => '#FFFFFF', 'accent' => '#06C755' }
    }
  end

  describe 'GET /api/v1/accounts/{account.id}/card_designs' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/card_designs"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      let!(:custom_design) { create(:card_design, account: account, name: 'Custom') }
      let!(:builtin_design) { create(:card_design, :builtin, account: account, name: 'Built-in') }

      it 'returns all card designs for the account' do
        get "/api/v1/accounts/#{account.id}/card_designs",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        data = response.parsed_body
        expect(data.length).to eq(2)
      end

      it 'returns built-in designs first' do
        get "/api/v1/accounts/#{account.id}/card_designs",
            headers: agent.create_new_auth_token,
            as: :json

        data = response.parsed_body
        expect(data.first['is_builtin']).to be true
      end

      it 'does not return designs from other accounts' do
        other_account = create(:account)
        create(:card_design, account: other_account, name: 'Other')

        get "/api/v1/accounts/#{account.id}/card_designs",
            headers: agent.create_new_auth_token,
            as: :json

        data = response.parsed_body
        expect(data.length).to eq(2)
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/card_designs/:id' do
    let!(:card_design) { create(:card_design, account: account) }

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/card_designs/#{card_design.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      it 'returns the card design' do
        get "/api/v1/accounts/#{account.id}/card_designs/#{card_design.id}",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        data = response.parsed_body
        expect(data['id']).to eq(card_design.id)
        expect(data['name']).to eq(card_design.name)
        expect(data['design_json']).to eq(card_design.design_json)
      end

      it 'returns 404 for non-existent design' do
        get "/api/v1/accounts/#{account.id}/card_designs/0",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/card_designs' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/card_designs",
             params: { card_design: { name: 'Test', design_json: valid_design_json } },
             as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      it 'creates a new card design' do
        expect do
          post "/api/v1/accounts/#{account.id}/card_designs",
               headers: agent.create_new_auth_token,
               params: { card_design: { name: 'My Design', design_json: valid_design_json } },
               as: :json
        end.to change(CardDesign, :count).by(1)

        expect(response).to have_http_status(:success)
        data = response.parsed_body
        expect(data['name']).to eq('My Design')
        expect(data['is_builtin']).to be false
        expect(data['is_default']).to be false
      end

      it 'returns error for invalid params' do
        post "/api/v1/accounts/#{account.id}/card_designs",
             headers: agent.create_new_auth_token,
             params: { card_design: { name: '', design_json: valid_design_json } },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/card_designs/:id' do
    let!(:card_design) { create(:card_design, account: account) }

    context 'when authenticated' do
      it 'updates a custom card design' do
        patch "/api/v1/accounts/#{account.id}/card_designs/#{card_design.id}",
              headers: agent.create_new_auth_token,
              params: { card_design: { name: 'Updated Name' } },
              as: :json

        expect(response).to have_http_status(:success)
        expect(card_design.reload.name).to eq('Updated Name')
      end

      it 'returns 403 for built-in designs' do
        builtin = create(:card_design, :builtin, account: account, name: 'Built-in')

        patch "/api/v1/accounts/#{account.id}/card_designs/#{builtin.id}",
              headers: agent.create_new_auth_token,
              params: { card_design: { name: 'Renamed' } },
              as: :json

        expect(response).to have_http_status(:forbidden)
        expect(builtin.reload.name).to eq('Built-in')
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/card_designs/:id' do
    context 'when authenticated' do
      it 'deletes a custom card design' do
        card_design = create(:card_design, account: account)

        expect do
          delete "/api/v1/accounts/#{account.id}/card_designs/#{card_design.id}",
                 headers: agent.create_new_auth_token,
                 as: :json
        end.to change(CardDesign, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      it 'returns 403 for built-in designs' do
        builtin = create(:card_design, :builtin, account: account, name: 'Built-in')

        expect do
          delete "/api/v1/accounts/#{account.id}/card_designs/#{builtin.id}",
                 headers: agent.create_new_auth_token,
                 as: :json
        end.not_to change(CardDesign, :count)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/card_designs/:id/set_default' do
    context 'when authenticated' do
      it 'sets the design as default' do
        card_design = create(:card_design, account: account)

        post "/api/v1/accounts/#{account.id}/card_designs/#{card_design.id}/set_default",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(card_design.reload.is_default).to be true
      end

      it 'unsets the previous default' do
        old_default = create(:card_design, :default, account: account, name: 'Old')
        new_default = create(:card_design, account: account, name: 'New')

        post "/api/v1/accounts/#{account.id}/card_designs/#{new_default.id}/set_default",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(new_default.reload.is_default).to be true
        expect(old_default.reload.is_default).to be false
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/card_designs/:id/duplicate' do
    context 'when authenticated' do
      it 'creates a copy of the design' do
        card_design = create(:card_design, account: account, name: 'Original')

        expect do
          post "/api/v1/accounts/#{account.id}/card_designs/#{card_design.id}/duplicate",
               headers: agent.create_new_auth_token,
               as: :json
        end.to change(CardDesign, :count).by(1)

        expect(response).to have_http_status(:success)
        data = response.parsed_body
        expect(data['name']).to eq('Original (Copy)')
        expect(data['is_builtin']).to be false
      end

      it 'duplicates built-in designs' do
        builtin = create(:card_design, :builtin, account: account, name: 'Built-in')

        post "/api/v1/accounts/#{account.id}/card_designs/#{builtin.id}/duplicate",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        data = response.parsed_body
        expect(data['name']).to eq('Built-in (Copy)')
        expect(data['is_builtin']).to be false
      end
    end
  end
end
