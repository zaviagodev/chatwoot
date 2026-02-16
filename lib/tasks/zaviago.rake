# Zaviago custom rake tasks
# Defense in Depth - Layer 3: Post-migration Captain protection

namespace :zaviago do
  desc 'Ensure Captain AI features are enabled (run after migrations)'
  task ensure_captain: :environment do
    puts '[Zaviago] Ensuring Captain AI features are enabled...'
    
    # 0. Ensure pricing plan is enterprise
    pricing_config = InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN')
    if pricing_config.value != 'enterprise'
      pricing_config.update!(value: 'enterprise')
      puts '[Zaviago] Set INSTALLATION_PRICING_PLAN to enterprise'
    else
      puts '[Zaviago] INSTALLATION_PRICING_PLAN already enterprise'
    end
    
    # 1. Find the feature defaults config
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    
    unless config
      puts '[Zaviago] ACCOUNT_LEVEL_FEATURE_DEFAULTS not found, skipping...'
      next
    end
    
    features = config.value
    changed = false
    
    # Enable all captain features
    features.each do |feature|
      if feature['name'].to_s.include?('captain')
        if feature['enabled'] != true
          feature['enabled'] = true
          changed = true
          puts "[Zaviago] Enabling feature: #{feature['name']}"
        end
        if feature.key?('premium')
          feature.delete('premium')
          changed = true
          puts "[Zaviago] Removed premium flag from: #{feature['name']}"
        end
      end
    end
    
    if changed
      config.value = features
      config.save!
      puts '[Zaviago] Captain features saved!'
    else
      puts '[Zaviago] Captain features already enabled.'
    end
    
    # Enable for all accounts
    Account.find_each do |account|
      needs_save = false
      
      %w[captain_integration captain_integration_v2 captain_tasks].each do |feature|
        unless account.feature_enabled?(feature)
          account.enable_features(feature)
          needs_save = true
          puts "[Zaviago] Enabled #{feature} for account: #{account.id}"
        end
      end
      
      if needs_save
        account.save!
        puts "[Zaviago] Saved account: #{account.id}"
      end
    end
    
    puts '[Zaviago] Done!'
  end
end

# Hook into db:migrate to run ensure_captain after migrations
# This is Layer 3 of Defense in Depth
Rake::Task['db:migrate'].enhance do
  puts ''
  puts '[Zaviago] Running post-migration Captain check...'
  Rake::Task['zaviago:ensure_captain'].invoke
end
