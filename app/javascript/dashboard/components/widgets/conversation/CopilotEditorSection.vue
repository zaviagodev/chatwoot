<script setup>
import { ref } from 'vue';
import CopilotEditor from 'dashboard/components/widgets/WootWriter/CopilotEditor.vue';
import CaptainLoader from 'dashboard/components/widgets/conversation/copilot/CaptainLoader.vue';

defineProps({
  showCopilotEditor: {
    type: Boolean,
    default: false,
  },
  isGeneratingContent: {
    type: Boolean,
    default: false,
  },
  generatedContent: {
    type: String,
    default: '',
  },
  isPopout: {
    type: Boolean,
    default: false,
  },
  hasPreviousDraft: {
    type: Boolean,
    default: false,
  },
  hasNextDraft: {
    type: Boolean,
    default: false,
  },
  draftCounter: {
    type: String,
    default: '',
  },
});

const emit = defineEmits([
  'focus',
  'blur',
  'clearSelection',
  'contentReady',
  'send',
  'navigatePrevious',
  'navigateNext',
]);

const copilotEditorContent = ref('');
const editedDraftContent = ref('');

const onEditedContentUpdate = content => {
  editedDraftContent.value = content;
};

defineExpose({ editedDraftContent });

const onFocus = () => {
  emit('focus');
};

const onBlur = () => {
  emit('blur');
};

const clearEditorSelection = () => {
  emit('clearSelection');
};

const onSend = () => {
  emit('send', copilotEditorContent.value);
  copilotEditorContent.value = '';
};
</script>

<template>
  <div
    v-if="hasPreviousDraft || hasNextDraft || draftCounter"
    class="flex items-center justify-between px-4 py-1"
  >
    <button
      :disabled="!hasPreviousDraft"
      class="text-n-slate-11 hover:text-n-slate-12 disabled:opacity-30 disabled:cursor-not-allowed p-1"
      @click="$emit('navigatePrevious')"
    >
      <span class="i-lucide-chevron-left size-4" />
    </button>
    <span v-if="draftCounter" class="text-xs text-n-slate-10">
      {{ draftCounter }}
    </span>
    <button
      :disabled="!hasNextDraft"
      class="text-n-slate-11 hover:text-n-slate-12 disabled:opacity-30 disabled:cursor-not-allowed p-1"
      @click="$emit('navigateNext')"
    >
      <span class="i-lucide-chevron-right size-4" />
    </button>
  </div>
  <Transition
    mode="out-in"
    enter-active-class="transition-all duration-300 ease-out"
    enter-from-class="opacity-0 translate-y-2 scale-[0.98]"
    enter-to-class="opacity-100 translate-y-0 scale-100"
    leave-active-class="transition-all duration-200 ease-in"
    leave-from-class="opacity-100 translate-y-0 scale-100"
    leave-to-class="opacity-0 translate-y-2 scale-[0.98]"
    @after-enter="emit('contentReady')"
  >
    <CopilotEditor
      v-if="showCopilotEditor && !isGeneratingContent"
      key="copilot-editor"
      v-model="copilotEditorContent"
      class="copilot-editor"
      :generated-content="generatedContent"
      :min-height="4"
      :enabled-menu-options="[]"
      :is-popout="isPopout"
      @update:edited-content="onEditedContentUpdate"
      @focus="onFocus"
      @blur="onBlur"
      @clear-selection="clearEditorSelection"
      @send="onSend"
    />
    <div
      v-else-if="isGeneratingContent"
      key="loading-state"
      class="bg-n-iris-5 rounded min-h-16 w-full mb-4 p-4 flex items-start"
    >
      <div class="flex items-center gap-2">
        <CaptainLoader class="text-n-iris-10 size-4" />
        <span class="text-sm text-n-iris-10">
          {{ $t('CONVERSATION.REPLYBOX.COPILOT_THINKING') }}
        </span>
      </div>
    </div>
  </Transition>
</template>

<style lang="scss">
.copilot-editor {
  .ProseMirror-menubar {
    display: none;
  }
}
</style>
