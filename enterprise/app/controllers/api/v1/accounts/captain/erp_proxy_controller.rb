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

  def product_detail
    result = erp_client.get_product_detail(item_code: params[:item_code])
    render_result(result)
  end

  def variants
    result = erp_client.get_variants(item_code: params[:item_code])
    render_result(result)
  end

  def customization
    result = erp_client.get_customization(item_code: params[:item_code])
    render_result(result)
  end

  def upload_file
    result = erp_client.upload_customization_file(file: params[:file])
    render_result(result)
  end

  def bundle_info
    result = erp_client.get_bundle_info(item_code: params[:item_code])
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

  def create_shared_checkout
    result = erp_client.create_shared_checkout(
      items: params[:items],
      customer_email: params[:customer_email],
      address_name: params[:address_name],
      address_data: params[:address_data],
      line_user_id: params[:line_user_id],
      register_customer: params[:register_customer],
      conversation_id: params[:conversation_id]
    )
    render_result(result)
  end

  def lookup_line_customer
    result = erp_client.lookup_line_customer(
      line_user_id: params[:line_user_id]
    )
    render_result(result)
  end

  def search_thai_address
    result = erp_client.search_thai_address(query: params[:query])
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
