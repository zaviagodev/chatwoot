require 'rails_helper'

RSpec.describe Captain::PauseExpiryJob, type: :job do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  before do
    conversation.update!(additional_attributes: { 'copilot_mode' => 'auto_send' })
  end

  describe '#perform' do
    context 'when conversation is timed-paused with matching nonce' do
      before do
        conversation.pause_ai!(mode: 'timed', duration_minutes: 60)
      end

      it 'resumes AI on the conversation' do
        nonce = conversation.additional_attributes['pause_nonce']

        described_class.new.perform(conversation, nonce)
        conversation.reload

        expect(conversation.copilot_mode).to eq('auto_send')
        expect(conversation.additional_attributes['pause_mode']).to be_nil
        expect(conversation.additional_attributes['pause_nonce']).to be_nil
        expect(conversation.additional_attributes['pause_expires_at']).to be_nil
      end
    end

    context 'when conversation was manually resumed before job fires' do
      before do
        conversation.pause_ai!(mode: 'timed', duration_minutes: 60)
      end

      it 'is a no-op' do
        nonce = conversation.additional_attributes['pause_nonce']
        conversation.resume_ai!

        expect {
          described_class.new.perform(conversation, nonce)
        }.not_to(change { conversation.reload.additional_attributes })
      end
    end

    context 'when pause mode was changed to permanent' do
      before do
        conversation.pause_ai!(mode: 'timed', duration_minutes: 60)
      end

      it 'is a no-op' do
        nonce = conversation.additional_attributes['pause_nonce']
        # Simulate: agent resumed then re-paused as permanent
        conversation.resume_ai!
        conversation.pause_ai!(mode: 'permanent')

        expect {
          described_class.new.perform(conversation, nonce)
        }.not_to(change { conversation.reload.copilot_mode })
      end
    end

    context 'when nonce does not match (re-paused scenario)' do
      before do
        conversation.pause_ai!(mode: 'timed', duration_minutes: 60)
      end

      it 'is a no-op — stale job does not resume the new pause' do
        old_nonce = conversation.additional_attributes['pause_nonce']

        # Agent resumes and re-pauses with a new timer
        conversation.resume_ai!
        conversation.pause_ai!(mode: 'timed', duration_minutes: 120)
        new_nonce = conversation.reload.additional_attributes['pause_nonce']

        expect(old_nonce).not_to eq(new_nonce)

        # Old job fires with old nonce — should be no-op
        described_class.new.perform(conversation, old_nonce)
        conversation.reload

        expect(conversation.ai_paused?).to be true
        expect(conversation.additional_attributes['pause_mode']).to eq('timed')
        expect(conversation.additional_attributes['pause_nonce']).to eq(new_nonce)
      end
    end
  end
end
