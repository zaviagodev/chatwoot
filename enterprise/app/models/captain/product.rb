class Captain::Product < ApplicationRecord
  self.table_name = 'captain_products'

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'
  has_many :responses, class_name: 'Captain::AssistantResponse',
           as: :documentable, dependent: :destroy

  validates :item_code, presence: true,
            uniqueness: { scope: [:account_id, :assistant_id], message: 'already exists for this assistant' }
  validates :item_name, presence: true
  validates :description_source, inclusion: { in: %w[auto ai manual] }
  validates :status, inclusion: { in: %w[active draft archived] }, allow_nil: true

  scope :ordered, -> { order(created_at: :desc) }
  scope :active, -> { where(status: 'active') }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_assistant, ->(assistant_id) { where(assistant_id: assistant_id) }
  scope :in_stock, -> { where(stock_status: 'in_stock') }

  def in_stock?
    stock_qty.to_f > 0
  end

  def update_stock(qty)
    new_status = qty.to_f > 0 ? 'in_stock' : 'out_of_stock'
    update(stock_qty: qty, stock_status: new_status)
  end
end
