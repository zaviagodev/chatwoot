require 'rails_helper'

RSpec.describe CardDesign do
  let(:account) { create(:account) }

  describe 'validations' do
    it 'validates name presence' do
      card_design = build(:card_design, account: account, name: nil)
      expect(card_design).not_to be_valid
      expect(card_design.errors[:name]).to include("can't be blank")
    end

    it 'validates name uniqueness per account' do
      create(:card_design, account: account, name: 'My Design')
      duplicate = build(:card_design, account: account, name: 'My Design')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('has already been taken')
    end

    it 'allows same name across different accounts' do
      other_account = create(:account)
      create(:card_design, account: account, name: 'My Design')
      other_design = build(:card_design, account: other_account, name: 'My Design')
      expect(other_design).to be_valid
    end

    it 'validates design_json presence' do
      card_design = build(:card_design, account: account, design_json: nil)
      expect(card_design).not_to be_valid
    end

    it 'validates design_json must have sections and colors keys' do
      card_design = build(:card_design, account: account, design_json: { 'invalid' => true })
      expect(card_design).not_to be_valid
      expect(card_design.errors[:design_json]).to include('must contain sections and colors keys')
    end

    it 'rejects design_json with title section disabled' do
      design_json = {
        'sections' => {
          'hero' => { 'enabled' => true, 'aspect_ratio' => '20:13' },
          'title' => { 'enabled' => false, 'size' => 'lg', 'weight' => 'bold' },
          'subtitle' => { 'enabled' => false, 'size' => 'md', 'color' => '#999999' },
          'price' => { 'enabled' => true, 'size' => 'md', 'color' => '#666666' },
          'button' => { 'enabled' => true, 'label' => 'View', 'style' => 'primary' }
        },
        'colors' => { 'background' => '#FFFFFF', 'accent' => '#06C755' }
      }
      card_design = build(:card_design, account: account, design_json: design_json)
      expect(card_design).not_to be_valid
      expect(card_design.errors[:design_json]).to include('title section cannot be disabled')
    end

    it 'prevents modification of built-in designs' do
      card_design = create(:card_design, :builtin, account: account)
      card_design.name = 'New Name'
      expect(card_design).not_to be_valid
      expect(card_design.errors[:base]).to include('Built-in designs cannot be modified')
    end
  end

  describe '#set_as_default!' do
    it 'sets the design as default and unsets previous default' do
      old_default = create(:card_design, :default, account: account, name: 'Old Default')
      new_default = create(:card_design, account: account, name: 'New Default')

      new_default.set_as_default!

      expect(new_default.reload.is_default).to be true
      expect(old_default.reload.is_default).to be false
    end

    it 'works when no previous default exists' do
      design = create(:card_design, account: account)
      expect { design.set_as_default! }.not_to raise_error
      expect(design.reload.is_default).to be true
    end
  end

  describe '#increment_usage!' do
    it 'increments the usage count by 1' do
      design = create(:card_design, account: account)
      expect { design.increment_usage! }.to change { design.reload.usage_count }.from(0).to(1)
    end
  end

  describe '#duplicate!' do
    it 'creates a copy with "(Copy)" suffix' do
      design = create(:card_design, account: account, name: 'Original')
      copy = design.duplicate!

      expect(copy).to be_persisted
      expect(copy.name).to eq('Original (Copy)')
      expect(copy.design_json).to eq(design.design_json)
      expect(copy.is_builtin).to be false
      expect(copy.is_default).to be false
    end

    it 'allows custom name for the copy' do
      design = create(:card_design, account: account, name: 'Original')
      copy = design.duplicate!(new_name: 'Custom Name')
      expect(copy.name).to eq('Custom Name')
    end

    it 'can duplicate built-in designs' do
      design = create(:card_design, :builtin, account: account, name: 'Built-in')
      copy = design.duplicate!

      expect(copy).to be_persisted
      expect(copy.is_builtin).to be false
    end
  end

  describe '.seed_builtin_designs_for' do
    it 'creates 4 built-in designs for the account' do
      expect { described_class.seed_builtin_designs_for(account) }
        .to change { account.card_designs.where(is_builtin: true).count }.by(4)
    end

    it 'sets Product design as default' do
      described_class.seed_builtin_designs_for(account)
      product = account.card_designs.find_by(name: 'Product', is_builtin: true)
      expect(product.is_default).to be true
    end

    it 'is idempotent' do
      described_class.seed_builtin_designs_for(account)
      expect { described_class.seed_builtin_designs_for(account) }
        .not_to(change { account.card_designs.count })
    end

    it 'creates all 4 design types' do
      described_class.seed_builtin_designs_for(account)
      names = account.card_designs.where(is_builtin: true).pluck(:name)
      expect(names).to contain_exactly('Product', 'Promotion', 'Event', 'Announcement')
    end
  end

  describe '.ordered' do
    it 'returns built-in designs first, then by created_at' do
      custom = create(:card_design, account: account, name: 'Custom')
      builtin = create(:card_design, :builtin, account: account, name: 'Built-in')

      results = account.card_designs.ordered
      expect(results.first).to eq(builtin)
      expect(results.last).to eq(custom)
    end
  end
end
