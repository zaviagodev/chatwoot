# Zaviago Captain AI Auto-Enable Initializer
# Defense in Depth - Layer 1
#
# This initializer ensures Captain AI features are always enabled,
# regardless of upstream migrations or database seeds.
#
# Runs on every Rails boot.

Rails.application.config.after_initialize do
  next unless ActiveRecord::Base.connection.table_exists?('installation_configs')

  Rails.logger.info '[Zaviago] Ensuring Captain AI features are enabled...'

  begin
    # 0. Ensure pricing plan is set to enterprise (required for Captain UI)
    pricing_config = InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN')
    if pricing_config.value != 'enterprise'
      pricing_config.update!(value: 'enterprise')
      Rails.logger.info '[Zaviago] Set INSTALLATION_PRICING_PLAN to enterprise'
    end

    # 1. Enable in ACCOUNT_LEVEL_FEATURE_DEFAULTS
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')

    if config
      features = config.value
      changed = false

      features.each do |f|
        if f['name'].to_s.include?('captain')
          if f['enabled'] != true
            f['enabled'] = true
            changed = true
            Rails.logger.info "[Zaviago] Enabled feature default: #{f['name']}"
          end
          if f.key?('premium')
            f.delete('premium')
            changed = true
            Rails.logger.info "[Zaviago] Removed premium flag from: #{f['name']}"
          end
        end
      end

      if changed
        config.value = features
        config.save!
        Rails.logger.info '[Zaviago] Captain feature defaults saved!'
      end
    end

    # 2. Enable for all accounts (with proper save)
    Account.find_each do |account|
      needs_save = false

      %w[captain_integration captain_integration_v2 captain_tasks].each do |feature|
        unless account.feature_enabled?(feature)
          account.enable_features(feature)
          needs_save = true
          Rails.logger.info "[Zaviago] Enabled #{feature} for account: #{account.id}"
        end
      end

      if needs_save
        account.save!
        Rails.logger.info "[Zaviago] Saved account: #{account.id}"
      end
    end

  rescue => e
    Rails.logger.error "[Zaviago] Error ensuring Captain: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end
end
