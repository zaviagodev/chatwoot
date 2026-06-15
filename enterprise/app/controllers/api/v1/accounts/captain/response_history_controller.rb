class Api::V1::Accounts::Captain::ResponseHistoryController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action :set_assistant
  before_action :set_current_page, only: [:index]

  RESULTS_PER_PAGE = 25

  def index
    base_scope = Current.account
                        .messages
                        .where("content_attributes::text LIKE ?", '%generated_by%captain%')
                        .order(created_at: :desc)

    base_scope = base_scope.where('content ILIKE ?', "%#{params[:search]}%") if params[:search].present?

    @responses_count = base_scope.count
    @responses = base_scope.includes(:conversation).page(@current_page).per(RESULTS_PER_PAGE)
  end

  private

  def check_authorization
    raise Pundit::NotAuthorizedError unless Current.account_user.administrator? || Current.account_user.agent?
  end

  def set_assistant
    @assistant = Current.account.captain_assistants.find(params[:assistant_id])
  end

  def set_current_page
    @current_page = params[:page] || 1
  end
end
