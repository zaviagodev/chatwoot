json.payload do
  json.array! @contacts do |conversation_contact|
    contact = conversation_contact.contact
    json.id contact.id
    json.name contact.name
    json.email contact.email
    json.phone_number contact.phone_number
    json.thumbnail contact.avatar_url
    json.joined_at conversation_contact.created_at.to_i
  end
end
