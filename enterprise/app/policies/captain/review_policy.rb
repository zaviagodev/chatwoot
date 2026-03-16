class Captain::ReviewPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def distinct_categories?
    true
  end

  def bulk_destroy?
    @account_user.administrator?
  end
end
