class Captain::Products::StockSyncJob < ApplicationJob
  queue_as :scheduled_jobs

  DEFAULT_INTERVAL = 3600

  def perform
    Captain::Assistant.joins(:products).distinct.find_each do |assistant|
      next unless sync_due?(assistant)

      Captain::Products::StockSyncService.new(assistant: assistant).sync
    rescue StandardError => e
      Rails.logger.error("[StockSyncJob] Failed for assistant #{assistant.id}: #{e.message}")
    end
  end

  private

  def sync_due?(assistant)
    interval = (assistant.sync_interval || DEFAULT_INTERVAL).to_i
    last_sync = parse_last_synced(assistant.last_synced_at)
    last_sync < interval.seconds.ago
  end

  def parse_last_synced(value)
    return Time.at(0) if value.blank?

    Time.parse(value)
  rescue ArgumentError
    Time.at(0)
  end
end
