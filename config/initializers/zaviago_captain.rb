# Zaviago Customization: Ensure Captain AI is always enabled
# This runs on every Rails boot to prevent Captain from being disabled
# by upstream migrations or database seeds.

Rails.application.config.after_initialize do
  # Skip in test/development console without database
  next unless ActiveRecord::Base.connection.table_exists?('installation_configs')

  Rails.logger.info '[Zaviago] Ensuring Captain AI features are enabled...'

  begin
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return unless config

    features = config.value
    changed = false

    features.each do |f|
      if f['name'].to_s.include?('captain') && f['enabled'] != true
        f['enabled'] = true
        f.delete('premium')
        changed = true
        Rails.logger.info "[Zaviago] Enabled feature: #{f['name']}"
      end
    end

    if changed
      config.value = features
      config.save!
      Rails.logger.info '[Zaviago] Captain features restored!'
    end

    # Enable for all accounts that don't have it
    Account.find_each do |account|
      unless account.feature_enabled?('captain_integration')
        account.enable_features('captain_integration', 'captain_integration_v2', 'captain_tasks')
        Rails.logger.info "[Zaviago] Enabled Captain for account: #{account.id}"
      end
    end
  rescue => e
    Rails.logger.error "[Zaviago] Error ensuring Captain: #{e.message}"
  end
end
