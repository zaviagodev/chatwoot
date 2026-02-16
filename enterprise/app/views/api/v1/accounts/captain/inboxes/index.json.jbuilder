copilot_modes = @assistant.captain_inboxes.pluck(:inbox_id, :copilot_default_mode).to_h

json.payload do
  json.array! @inboxes do |inbox|
    json.partial! 'api/v1/models/inbox', formats: [:json], resource: inbox
    json.copilot_default_mode copilot_modes[inbox.id] || 'draft'
  end
end

json.meta do
  json.total_count @inboxes.count
  json.page 1
end
