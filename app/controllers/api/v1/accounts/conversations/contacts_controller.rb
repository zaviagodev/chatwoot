class Api::V1::Accounts::Conversations::ContactsController < Api::V1::Accounts::Conversations::BaseController
  def show
    @contacts = @conversation.conversation_contacts.includes(:contact)
  end
end
