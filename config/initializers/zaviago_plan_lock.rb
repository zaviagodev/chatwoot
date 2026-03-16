# Zaviago Plan Lock - Prevents ChatwootHub from resetting our enterprise plan
# Defense in Depth - Layer 0 (root cause fix)
#
# The enterprise CheckNewVersionsJob periodically pings hub.2.chatwoot.com
# which returns plan: 'community' (no paid license). The job then overwrites
# INSTALLATION_PRICING_PLAN and disables all premium features.
#
# This initializer patches the job to skip the plan update, keeping our
# locally-set enterprise plan intact.
#
# See: docs/postmortems/2026-02-16-chatwoot-enterprise-plan-reversion.md

Rails.application.config.after_initialize do
  if defined?(Enterprise::Internal::CheckNewVersionsJob)
    Enterprise::Internal::CheckNewVersionsJob.module_eval do
      private

      # Override: Never let the hub response overwrite our plan
      def update_plan_info
        return if @instance_info.blank?

        # Only sync non-plan configs (support widget token, etc.)
        # SKIP: INSTALLATION_PRICING_PLAN and INSTALLATION_PRICING_PLAN_QUANTITY
        update_installation_config(key: 'CHATWOOT_SUPPORT_WEBSITE_TOKEN', value: @instance_info['chatwoot_support_website_token'])
        update_installation_config(key: 'CHATWOOT_SUPPORT_IDENTIFIER_HASH', value: @instance_info['chatwoot_support_identifier_hash'])
        update_installation_config(key: 'CHATWOOT_SUPPORT_SCRIPT_URL', value: @instance_info['chatwoot_support_script_url'])

        Rails.logger.info '[Zaviago] Skipped hub plan override — keeping enterprise plan'
      end

      # Override: Never reconcile (disable) premium features
      def reconcile_premium_config_and_features
        Rails.logger.info '[Zaviago] Skipped premium feature reconciliation — features stay enabled'
      end
    end

    # Also patch the base job's version check to suppress the "new version" banner.
    # Our fork is pinned; the hub always reports a newer version, showing a
    # blue bar to all admin users.
    Internal::CheckNewVersionsJob.prepend(Module.new do
      private

      def update_version_info
        Rails.logger.info '[Zaviago] Skipped hub version sync — suppressing update banner'
      end
    end)

    Rails.logger.info '[Zaviago] Plan lock installed — CheckNewVersionsJob patched'
  end
end
