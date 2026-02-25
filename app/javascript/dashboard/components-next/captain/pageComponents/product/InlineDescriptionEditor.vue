<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  product: {
    type: Object,
    required: true,
  },
  mode: {
    type: String,
    default: 'view',
    validator: value => ['view', 'edit'].includes(value),
  },
  assistantId: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['saved', 'close', 'edit']);
const store = useStore();
const { t } = useI18n();

const editText = ref(props.product.formatted_text || '');
const isSaving = ref(false);

const isEditing = computed(() => props.mode === 'edit');

const handleSave = async () => {
  if (!editText.value.trim()) return;
  isSaving.value = true;

  try {
    await store.dispatch('captainProducts/update', {
      assistantId: props.assistantId,
      id: props.product.id,
      text: editText.value,
      source: 'manual',
    });
    useAlert(t('CAPTAIN_PRODUCTS.TOAST.UPDATED'));
    emit('saved');
  } catch {
    useAlert(t('CAPTAIN_PRODUCTS.TOAST.SYNC_ERROR'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div
    class="p-4 -mt-2 rounded-b-lg border border-t-0 bg-n-alpha-1 border-n-weak"
  >
    <!-- View mode -->
    <div v-if="!isEditing" class="flex flex-col gap-3">
      <pre
        class="text-sm text-n-slate-11 whitespace-pre-wrap font-sans leading-relaxed"
        >{{
          product.formatted_text ||
          $t('CAPTAIN_PRODUCTS.INLINE_EDITOR.NO_DESCRIPTION')
        }}</pre
      >
      <div class="flex gap-2 justify-end">
        <Button
          variant="faded"
          color="slate"
          size="xs"
          :label="$t('CAPTAIN_PRODUCTS.INLINE_EDITOR.EDIT')"
          icon="i-lucide-pencil"
          @click="emit('edit')"
        />
        <Button
          variant="faded"
          color="slate"
          size="xs"
          :label="$t('CAPTAIN_PRODUCTS.INLINE_EDITOR.CLOSE')"
          icon="i-lucide-x"
          @click="emit('close')"
        />
      </div>
    </div>

    <!-- Edit mode -->
    <div v-else class="flex flex-col gap-3">
      <textarea
        v-model="editText"
        rows="8"
        class="w-full p-3 text-sm rounded-lg border resize-y bg-n-alpha-1 border-n-weak text-n-slate-12 focus:border-b-500 focus:outline-none"
      />
      <div class="flex gap-2 justify-end">
        <Button
          variant="faded"
          color="slate"
          size="xs"
          :label="$t('CAPTAIN_PRODUCTS.INLINE_EDITOR.CANCEL')"
          @click="emit('close')"
        />
        <Button
          size="xs"
          :label="$t('CAPTAIN_PRODUCTS.INLINE_EDITOR.SAVE')"
          :is-loading="isSaving"
          :disabled="!editText.trim() || isSaving"
          @click="handleSave"
        />
      </div>
    </div>
  </div>
</template>
