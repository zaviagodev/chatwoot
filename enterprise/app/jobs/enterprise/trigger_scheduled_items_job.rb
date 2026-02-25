module Enterprise::TriggerScheduledItemsJob
  def perform
    super

    ## Triggers Enterprise specific jobs
    ####################################

    # Triggers Account Sla jobs
    Sla::TriggerSlasForAccountsJob.perform_later

    # Triggers Captain product stock sync
    Captain::Products::StockSyncJob.perform_later
  end
end
