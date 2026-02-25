class Api::V1::Accounts::Captain::ProductsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Captain::Product) }
  before_action :set_assistant
  before_action :set_current_page, only: [:index]
  before_action :set_product, only: [:show, :update, :destroy, :enrich, :approve_enrichment]

  RESULTS_PER_PAGE = 25

  def index
    @products = @assistant.products.ordered
    @products = @products.where(item_group: params[:item_group]) if params[:item_group].present?
    @products_count = @products.count
    @products = @products.page(@current_page).per(RESULTS_PER_PAGE)
  end

  def show; end

  def create
    service = Captain::Products::ManageService.new(assistant: @assistant, account: Current.account)
    @product = service.create(product_params)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    service = Captain::Products::ManageService.new(assistant: @assistant, account: Current.account)
    if params[:text].present?
      service.update_description(@product, text: params[:text], source: params[:source] || 'manual')
    else
      service.update(@product, product_params, reset_source: params[:reset_source] == 'true')
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    service = Captain::Products::ManageService.new(assistant: @assistant, account: Current.account)
    service.destroy(@product)
    head :no_content
  end

  def sync
    result = Captain::Products::StockSyncService.new(assistant: @assistant).sync
    if result[:error]
      render json: result, status: :service_unavailable
    else
      render json: result
    end
  end

  def sync_status
    render json: {
      last_synced_at: @assistant.last_synced_at,
      sync_error_count: (@assistant.sync_error_count || 0).to_i,
      sync_interval: (@assistant.sync_interval || Captain::Products::StockSyncService::DEFAULT_SYNC_INTERVAL).to_i
    }
  end

  def enrich
    result = Captain::Products::AiEnrichService.new(product: @product).enrich
    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: result
    end
  end

  def approve_enrichment
    return render json: { error: 'text is required' }, status: :unprocessable_entity if params[:text].blank?

    service = Captain::Products::ManageService.new(assistant: @assistant, account: Current.account)
    @product = service.update_description(@product, text: params[:text], source: 'ai')
    render partial: 'api/v1/models/captain/product', locals: { product: @product }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def provision_tools
    result = Captain::Products::ToolProvisioningService.new(assistant: @assistant).provision_tools
    render json: result
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_assistant
    @assistant = Current.account.captain_assistants.find(params[:assistant_id])
  end

  def set_product
    @product = @assistant.products.find(params[:id])
  end

  def set_current_page
    @current_page = params[:page] || 1
  end

  def product_params
    params.permit(
      :item_code, :item_name, :description, :price, :currency,
      :stock_qty, :item_group, :image, :formatted_text, :erp_company,
      variants: [:item_code, :item_name, :image],
      specs: [:label, :value]
    )
  end
end
