<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

export default {
  name: 'CopilotDraftBanner',
  emits: ['edit'],
  computed: {
    ...mapGetters({
      draft: 'getCopilotDraft',
      uiFlags: 'getCopilotDraftUIFlags',
    }),
    draftContent() {
      return this.draft?.content || '';
    },
    conversationId() {
      return this.draft?.conversation_display_id || this.draft?.conversation_id;
    },
    isApproving() {
      return this.uiFlags?.isApproving || false;
    },
    isRejecting() {
      return this.uiFlags?.isRejecting || false;
    },
    isProcessing() {
      return this.isApproving || this.isRejecting;
    },
  },
  methods: {
    async onApprove() {
      if (this.isProcessing) return;
      try {
        await this.$store.dispatch('approveCopilotDraft', this.conversationId);
        useAlert(this.$t('CONVERSATION.COPILOT_DRAFT.APPROVED'));
      } catch (error) {
        useAlert(this.$t('CONVERSATION.COPILOT_DRAFT.ERROR'));
      }
    },
    async onReject() {
      if (this.isProcessing) return;
      // Capture everything BEFORE dispatching — CLEAR_COPILOT_DRAFT
      // nulls the draft, which unmounts this component (v-if="draft").
      // After unmount, this.$t() and this.$store may be unavailable.
      const conversationId = this.conversationId;
      const store = this.$store;
      const rejectedMsg = this.$t('CONVERSATION.COPILOT_DRAFT.REJECTED');
      const undoMsg = this.$t('CONVERSATION.COPILOT_DRAFT.UNDO');
      const errorMsg = this.$t('CONVERSATION.COPILOT_DRAFT.ERROR');
      try {
        const result = await store.dispatch(
          'rejectCopilotDraft',
          conversationId
        );
        if (result?.success) {
          useAlert(rejectedMsg, {
            type: 'button',
            message: undoMsg,
            duration: 10000,
            callback: () => {
              store.dispatch('undoRejectCopilotDraft', conversationId);
            },
          });
        }
      } catch (error) {
        useAlert(errorMsg);
      }
    },
    onEdit() {
      this.$emit('edit', this.draftContent);
    },
  },
};
</script>

<template>
  <div
    v-if="draft"
    class="mx-2 mt-2 rounded-lg border border-n-strong bg-n-alpha-1 p-3"
  >
    <div class="flex items-center justify-between mb-2">
      <span class="text-xs font-medium text-n-slate-11">
        {{ $t('CONVERSATION.COPILOT_DRAFT.BANNER_MESSAGE') }}
      </span>
    </div>
    <div
      class="mb-3 rounded bg-n-background p-2 text-sm text-n-slate-12 whitespace-pre-wrap"
    >
      {{ draftContent }}
    </div>
    <div class="flex items-center gap-2">
      <woot-button
        size="small"
        :is-loading="isApproving"
        :is-disabled="isProcessing"
        @click="onApprove"
      >
        {{ $t('CONVERSATION.COPILOT_DRAFT.APPROVE') }}
      </woot-button>
      <woot-button
        size="small"
        variant="clear"
        color-scheme="secondary"
        :is-loading="isRejecting"
        :is-disabled="isProcessing"
        @click="onReject"
      >
        {{ $t('CONVERSATION.COPILOT_DRAFT.REJECT') }}
      </woot-button>
      <woot-button
        size="small"
        variant="clear"
        color-scheme="secondary"
        :is-disabled="isProcessing"
        @click="onEdit"
      >
        {{ $t('CONVERSATION.COPILOT_DRAFT.EDIT') }}
      </woot-button>
    </div>
  </div>
</template>
