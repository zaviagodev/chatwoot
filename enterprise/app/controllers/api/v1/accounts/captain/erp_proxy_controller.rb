class Api::V1::Accounts::Captain::ErpProxyController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Captain::Product) }
  before_action :set_assistant

  def search_products
    result = erp_client.search_products(
      query: params[:query],
      item_group: params[:item_group],
      page: (params[:page] || 1).to_i,
      page_size: (params[:page_size] || 20).to_i
    )
    render_result(result)
  end

  def item_groups
    result = erp_client.get_item_groups
    render_result(result)
  end

  def warehouses
    result = erp_client.get_warehouses
    render_result(result)
  end

  def setup
    @assistant.config ||= {}
    @assistant.erp_tenant_key = params[:erp_tenant_key] if params[:erp_tenant_key].present?
    @assistant.erp_company = params[:erp_company]
    @assistant.erp_warehouse = params[:erp_warehouse]
    @assistant.save!
    render json: { message: 'ERP connection configured' }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_assistant
    @assistant = Current.account.captain_assistants.find(params[:assistant_id])
  end

  def erp_client
    @erp_client ||= Captain::Erp::ApiClient.new(assistant: @assistant)
  end

  def render_result(result)
    if result.is_a?(Hash) && result[:error]
      render json: { error: result[:error] }, status: result[:status] || 502
    else
      render json: result
    end
  end
end
