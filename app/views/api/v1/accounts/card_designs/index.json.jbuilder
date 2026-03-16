json.array! @card_designs do |card_design|
  json.partial! 'api/v1/models/card_design', formats: [:json], resource: card_design
end
