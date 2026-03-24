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

  def upload_image
    return render json: { error: 'No image provided' }, status: :unprocessable_entity unless params[:image].present?

    blob = ActiveStorage::Blob.create_and_upload!(
      io: params[:image].tempfile,
      filename: params[:image].original_filename,
      content_type: params[:image].content_type
    )
    render json: { url: url_for(blob) }
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
      :description_source, :status,
      variants: [:item_code, :item_name, :image, :price, :stock_qty, :enabled,
                 :price_override, :description_override, { attributes: [:attribute, :value] }],
      specs: [:label, :value],
      option_groups: [:name, { values: [] }]
    )
  end
end
