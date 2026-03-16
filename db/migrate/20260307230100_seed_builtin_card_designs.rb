class SeedBuiltinCardDesigns < ActiveRecord::Migration[7.1]
  def up
    Account.find_each do |account|
      CardDesign.seed_builtin_designs_for(account)
    end
  end

  def down
    CardDesign.where(is_builtin: true).destroy_all
  end
end
