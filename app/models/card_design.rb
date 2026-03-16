class CardDesign < ApplicationRecord
  include CardDesignSeedable

  belongs_to :account

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :design_json, presence: true
  validate :validate_design_json_structure
  validate :prevent_builtin_modification, on: :update

  scope :ordered, -> { order(is_builtin: :desc, created_at: :asc) }

  def set_as_default!
    transaction do
      account.card_designs.where(is_default: true).update_all(is_default: false) # rubocop:disable Rails/SkipsModelValidations
      update!(is_default: true)
    end
  end

  def increment_usage!
    increment!(:usage_count) # rubocop:disable Rails/SkipsModelValidations
  end

  def duplicate!(new_name: nil)
    dup_name = new_name || "#{name} (Copy)"
    account.card_designs.create!(
      name: dup_name,
      design_json: design_json.deep_dup,
      is_default: false,
      is_builtin: false
    )
  end

  private

  def validate_design_json_structure
    return if design_json.blank?

    unless design_json.is_a?(Hash) && design_json.key?('sections') && design_json.key?('colors')
      errors.add(:design_json, 'must contain sections and colors keys')
      return
    end

    title_section = design_json.dig('sections', 'title')
    if title_section.is_a?(Hash) && title_section['enabled'] == false
      errors.add(:design_json, 'title section cannot be disabled')
    end
  end

  def prevent_builtin_modification
    errors.add(:base, 'Built-in designs cannot be modified') if is_builtin? && is_builtin_was
  end
end
