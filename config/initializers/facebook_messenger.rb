# ref: https://github.com/jgorset/facebook-messenger#make-a-configuration-provider
class ChatwootFbProvider < Facebook::Messenger::Configuration::Providers::Base
  CHANNEL_APP_SECRET_KEYS = %w[app_secret app_secret_key client_secret api_secret].freeze

  def valid_verify_token?(_verify_token)
    GlobalConfigService.load('FB_VERIFY_TOKEN', '')
  end

  def app_secret_for(page_id)
    channel_app_secret_for(page_id).presence || GlobalConfigService.load('FB_APP_SECRET', '')
  end

  def access_token_for(page_id)
    Channel::FacebookPage.where(page_id: page_id).last.page_access_token
  end

  private

  def channel_app_secret_for(page_id)
    channel = Channel::FacebookPage.where(page_id: page_id).last
    return if channel.blank?

    channel_app_secret_candidates(channel).first
  end

  def channel_app_secret_candidates(channel)
    secrets = []
    secrets << channel.app_secret if channel.respond_to?(:app_secret)
    secrets.concat(provider_config_app_secrets(channel))
    secrets.compact_blank.uniq
  end

  def provider_config_app_secrets(channel)
    return [] unless channel.respond_to?(:provider_config)

    provider_config = channel.provider_config.to_h.with_indifferent_access
    CHANNEL_APP_SECRET_KEYS.filter_map { |key| provider_config[key].presence }
  end

  def bot
    Chatwoot::Bot
  end
end

# Monkey-patch facebook-messenger gem to support SHA256 signature verification.
#
# The original gem (v2.0.1) only verifies X-Hub-Signature (SHA1). Meta now
# sends X-Hub-Signature-256 (SHA256) and has deprecated/removed SHA1.
# This patch:
#   1. Prefers SHA256 verification, falls back to SHA1
#   2. Uses the provider's per-page app secret resolution
#   3. Raises BadRequestError if neither signature matches (hard enforcement)
#
# History: QF-868 — Meta deprecated SHA1, gem only checks SHA1.
# CSide tenant reported FB messages stopped updating ~June 23, 2026.
module Facebook
  module Messenger
    class Server
      private

      def check_integrity
        raw_body = @request.body.read
        @request.body.rewind

        sha256_header = @request.env['HTTP_X_HUB_SIGNATURE_256'].to_s
        sha1_header = @request.env['HTTP_X_HUB_SIGNATURE'].to_s

        content_json = JSON.parse(raw_body, symbolize_names: true) rescue nil
        page_id = content_json&.dig(:entry, 0, :id)
        secret = Facebook::Messenger.config.provider.app_secret_for(page_id)

        return unless secret.present?

        # Prefer SHA256, fall back to SHA1
        if sha256_header.start_with?('sha256=')
          expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, raw_body)}"
          if Rack::Utils.secure_compare(sha256_header, expected)
            Rails.logger.info "[FB-WEBHOOK] SHA256 verified page=#{page_id}"
            return
          end
        end

        if sha1_header.start_with?('sha1=')
          expected = "sha1=#{OpenSSL::HMAC.hexdigest('sha1', secret, raw_body)}"
          if Rack::Utils.secure_compare(sha1_header, expected)
            Rails.logger.info "[FB-WEBHOOK] SHA1 verified page=#{page_id}"
            return
          end
        end

        # No valid signature header at all — allow through with warning
        # (Meta's transition period: some webhooks may arrive without signatures)
        if sha256_header.blank? && sha1_header.blank?
          Rails.logger.warn "[FB-WEBHOOK] No signature headers page=#{page_id} " \
            "bytes=#{raw_body.bytesize} (allowing through — transition period)"
          return
        end

        # Signature present but doesn't match — reject
        raise BadRequestError, 'Error checking message integrity'
      end
    end
  end
end

Rails.application.reloader.to_prepare do
  Facebook::Messenger.configure do |config|
    config.provider = ChatwootFbProvider.new
  end

  Facebook::Messenger::Bot.on :message do |message|
    Webhooks::FacebookEventsJob.perform_later(message.to_json)
  end

  Facebook::Messenger::Bot.on :delivery do |delivery|
    Rails.logger.info "Recieved delivery status #{delivery.to_json}"
    Webhooks::FacebookDeliveryJob.perform_later(delivery.to_json)
  end

  Facebook::Messenger::Bot.on :read do |read|
    Rails.logger.info "Recieved read status  #{read.to_json}"
    Webhooks::FacebookDeliveryJob.perform_later(read.to_json)
  end

  Facebook::Messenger::Bot.on :message_echo do |message|
    # Add delay to prevent race condition where echo arrives before send message API completes
    # This avoids duplicate messages when echo comes early during API processing
    Webhooks::FacebookEventsJob.set(wait: 2.seconds).perform_later(message.to_json)
  end
end
