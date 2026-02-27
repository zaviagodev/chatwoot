class Api::V1::Accounts::Captain::ReviewsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Captain::Review) }
  before_action :set_assistant
  before_action :set_current_page, only: [:index]
  before_action :set_review, only: [:show, :update, :destroy]

  RESULTS_PER_PAGE = 25

  def index
    base_scope = @assistant.reviews.ordered
    base_scope = base_scope.search(params[:search]) if params[:search].present?
    base_scope = base_scope.with_category(params[:category]) if params[:category].present?
    @reviews_count = base_scope.count
    @reviews = base_scope.with_attached_photos.includes(:product).page(@current_page).per(RESULTS_PER_PAGE)
  end

  def show; end

  def create
    service = Captain::Reviews::ManageService.new(assistant: @assistant, account: Current.account)
    @review = service.create(review_params)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    service = Captain::Reviews::ManageService.new(assistant: @assistant, account: Current.account)
    @review = service.update(@review, review_params)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    service = Captain::Reviews::ManageService.new(assistant: @assistant, account: Current.account)
    service.destroy(@review)
    head :no_content
  end

  def distinct_categories
    tags = @assistant.reviews
                     .where.not(category_tags: nil)
                     .where.not(category_tags: [])
                     .pluck(:category_tags)
                     .flatten.uniq.compact.sort
    render json: { categories: tags }
  end

  def bulk_destroy
    ids = params[:ids]
    return head :bad_request unless ids.is_a?(Array) && ids.any?
    return head :bad_request if ids.length > 100

    reviews = @assistant.reviews.where(id: ids)
    service = Captain::Reviews::ManageService.new(assistant: @assistant, account: Current.account)

    ActiveRecord::Base.transaction do
      reviews.find_each { |review| service.destroy(review) }
    end

    head :no_content
  end

  private

  def set_assistant
    @assistant = Current.account.captain_assistants.find(params[:assistant_id])
  end

  def set_review
    @review = @assistant.reviews.includes(:product).find(params[:id])
  end

  def set_current_page
    @current_page = params[:page] || 1
  end

  def review_params
    params.permit(:reviewer_name, :rating, :review_text, :captain_product_id, category_tags: [], photos: [], removed_photo_signed_ids: [])
  end
end
