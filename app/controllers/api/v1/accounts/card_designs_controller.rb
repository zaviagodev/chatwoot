class Api::V1::Accounts::CardDesignsController < Api::V1::Accounts::BaseController
  before_action :fetch_card_design, only: [:show, :update, :destroy, :set_default, :duplicate]

  def index
    @card_designs = Current.account.card_designs.ordered
  end

  def show; end

  def create
    @card_design = Current.account.card_designs.create!(card_design_params)
  end

  def update
    return render json: { error: 'Built-in designs cannot be modified' }, status: :forbidden if @card_design.is_builtin?

    @card_design.update!(card_design_params)
  end

  def destroy
    return render json: { error: 'Built-in designs cannot be deleted' }, status: :forbidden if @card_design.is_builtin?

    @card_design.destroy!
    head :no_content
  end

  def set_default
    @card_design.set_as_default!
  end

  def duplicate
    @new_card_design = @card_design.duplicate!
    @card_design = @new_card_design
    render :show
  end

  private

  def fetch_card_design
    @card_design = Current.account.card_designs.find(params[:id])
  end

  def card_design_params
    params.require(:card_design).permit(:name).tap do |permitted|
      permitted[:design_json] = params[:card_design][:design_json].permit!.to_h if params[:card_design][:design_json].present?
    end
  end
end
