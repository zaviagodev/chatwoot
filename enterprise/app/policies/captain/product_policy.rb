class Captain::ProductPolicy < ApplicationPolicy
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

  def sync?
    @account_user.administrator?
  end

  def sync_status?
    true
  end

  def enrich?
    @account_user.administrator?
  end

  def approve_enrichment?
    @account_user.administrator?
  end

  def provision_tools?
    @account_user.administrator?
  end

  # erp_proxy controller actions also use check_authorization(Captain::Product)
  def search_products?
    true
  end

  def item_groups?
    true
  end

  def warehouses?
    true
  end

  def setup?
    @account_user.administrator?
  end
end
