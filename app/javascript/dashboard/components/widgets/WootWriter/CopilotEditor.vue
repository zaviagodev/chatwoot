<script setup>
import { ref, computed, watch, onMounted, useTemplateRef } from 'vue';

import {
  buildMessageSchema,
  buildEditor,
  EditorView,
  MessageMarkdownTransformer,
  MessageMarkdownSerializer,
  EditorState,
  Selection,
} from '@chatwoot/prosemirror-schema';

import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  modelValue: { type: String, default: '' },
  editorId: { type: String, default: '' },
  placeholder: {
    type: String,
    default: 'Give copilot additional prompts, or ask anything else...',
  },
  generatedContent: { type: String, default: '' },
  autofocus: {
    type: Boolean,
    default: true,
  },
  isPopout: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'blur',
  'input',
  'update:modelValue',
  'update:editedContent',
  'keyup',
  'focus',
  'keydown',
  'send',
]);

// Minimal schema with no marks or nodes for copilot input
const copilotSchema = buildMessageSchema([], []);

const handleSubmit = () => emit('send');

const createState = (
  content,
  placeholder,
  plugins = [],
  enabledMenuOptions = []
) => {
  return EditorState.create({
    doc: new MessageMarkdownTransformer(copilotSchema).parse(content),
    plugins: buildEditor({
      schema: copilotSchema,
      placeholder,
      plugins,
      enabledMenuOptions,
    }),
  });
};

// --- Follow-up prompt editor (bottom input) ---
let editorView = null;
let state = null;

const isTextSelected = ref(false);
const editor = useTemplateRef('editor');

function contentFromEditor() {
  if (editorView) {
    return MessageMarkdownSerializer.serialize(editorView.state.doc);
  }
  return '';
}

function focusEditorInputField() {
  const { tr } = editorView.state;
  const selection = Selection.atEnd(tr.doc);
  editorView.dispatch(tr.setSelection(selection));
  editorView.focus();
}

function emitOnChange() {
  emit('update:modelValue', contentFromEditor());
  emit('input', contentFromEditor());
}

function onKeyup() {
  emit('keyup');
}

function onKeydown(view, event) {
  emit('keydown');
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault();
    handleSubmit();
    return true;
  }
  return false;
}

function onBlur() {
  emit('blur');
}

function onFocus() {
  emit('focus');
}

function checkSelection(editorState) {
  const hasSelection = editorState.selection.from !== editorState.selection.to;
  if (hasSelection === isTextSelected.value) return;
  isTextSelected.value = hasSelection;
}

const plugins = computed(() => []);
const enabledMenuOptions = computed(() => []);

function reloadState() {
  state = createState(
    props.modelValue,
    props.placeholder,
    plugins.value,
    enabledMenuOptions.value
  );
  editorView.updateState(state);
  focusEditorInputField();
}

function createEditorView() {
  editorView = new EditorView(editor.value, {
    state: state,
    dispatchTransaction: tx => {
      state = state.apply(tx);
      editorView.updateState(state);
      if (tx.docChanged) {
        emitOnChange();
      }
      checkSelection(state);
    },
    handleDOMEvents: {
      keyup: onKeyup,
      focus: onFocus,
      blur: onBlur,
      keydown: onKeydown,
    },
  });
}

// --- Draft content editor (editable generated content) ---
let draftEditorView = null;
let draftState = null;
const draftEditor = useTemplateRef('draftEditor');
const editedContent = ref('');
const isDraftModified = ref(false);

function contentFromDraftEditor() {
  if (draftEditorView) {
    return MessageMarkdownSerializer.serialize(draftEditorView.state.doc);
  }
  return '';
}

function createDraftEditorView() {
  if (!draftEditor.value) return;

  draftState = createState(props.generatedContent, '', [], []);
  draftEditorView = new EditorView(draftEditor.value, {
    state: draftState,
    dispatchTransaction: tx => {
      draftState = draftState.apply(tx);
      draftEditorView.updateState(draftState);
      if (tx.docChanged) {
        editedContent.value = contentFromDraftEditor();
        isDraftModified.value = editedContent.value !== props.generatedContent;
        emit('update:editedContent', editedContent.value);
      }
    },
  });
  editedContent.value = props.generatedContent;
}

function resetDraftToOriginal() {
  if (!draftEditorView) return;
  draftState = createState(props.generatedContent, '', [], []);
  draftEditorView.updateState(draftState);
  editedContent.value = props.generatedContent;
  isDraftModified.value = false;
  emit('update:editedContent', editedContent.value);
}

// Expose reset for parent components
defineExpose({ resetDraftToOriginal });

// --- Watchers ---
watch(
  computed(() => props.modelValue),
  (newValue = '') => {
    if (newValue !== contentFromEditor()) {
      reloadState();
    }
  }
);

watch(
  computed(() => props.editorId),
  () => {
    reloadState();
  }
);

// When generatedContent changes (new draft from Captain), reload draft editor
watch(
  computed(() => props.generatedContent),
  newContent => {
    if (draftEditorView && newContent) {
      draftState = createState(newContent, '', [], []);
      draftEditorView.updateState(draftState);
      editedContent.value = newContent;
      isDraftModified.value = false;
      emit('update:editedContent', newContent);
    }
  }
);

// --- Lifecycle ---
onMounted(() => {
  // Follow-up prompt editor
  state = createState(
    props.modelValue,
    props.placeholder,
    plugins.value,
    enabledMenuOptions.value
  );
  createEditorView();
  editorView.updateState(state);

  // Draft content editor
  if (props.generatedContent) {
    createDraftEditorView();
  }

  if (props.autofocus) {
    focusEditorInputField();
  }
});
</script>

<template>
  <div class="space-y-2 mb-4">
    <!-- Editable draft content -->
    <div
      v-if="generatedContent"
      class="overflow-y-auto"
      :class="{ 'max-h-96': isPopout, 'max-h-56': !isPopout }"
    >
      <div class="editor-root editor--draft">
        <div ref="draftEditor" />
      </div>
      <div v-if="isDraftModified" class="flex justify-end mt-1">
        <NextButton
          icon="i-lucide-undo-2"
          xs
          slate
          link
          class="!px-1"
          @click="resetDraftToOriginal"
        />
      </div>
    </div>
    <!-- Follow-up prompt editor -->
    <div class="editor-root relative editor--copilot space-x-2">
      <div ref="editor" />
      <div class="flex items-center justify-end absolute right-2 bottom-2">
        <NextButton
          class="bg-n-iris-9 text-white !rounded-full"
          icon="i-lucide-arrow-up"
          solid
          sm
          @click="handleSubmit"
        />
      </div>
    </div>
  </div>
</template>

<style lang="scss">
@import '@chatwoot/prosemirror-schema/src/styles/base.scss';

.editor--draft {
  .ProseMirror-woot-style {
    min-height: 3rem;
    max-height: none !important;
    overflow: auto;
    @apply text-n-iris-12 text-sm font-normal px-1;

    p {
      @apply mb-1;
    }
  }
}

.editor--copilot {
  @apply bg-n-iris-5 rounded;

  .ProseMirror-woot-style {
    min-height: 5rem;
    max-height: 7.5rem !important;
    overflow: auto;
    @apply px-2 !important;

    .empty-node {
      &::before {
        @apply text-n-iris-9 dark:text-n-iris-11;
      }
    }
  }
}
</style>
