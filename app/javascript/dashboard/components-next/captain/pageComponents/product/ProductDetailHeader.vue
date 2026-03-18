<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  productName: { type: String, default: '' },
  status: { type: String, default: 'active' },
  isDirty: { type: Boolean, default: false },
  isSaving: { type: Boolean, default: false },
  isErpSynced: { type: Boolean, default: false },
  isResyncing: { type: Boolean, default: false },
  canSave: { type: Boolean, default: false },
});

const emit = defineEmits(['save', 'delete', 'resync', 'back']);
const { t } = useI18n();

const statusBadgeClass = computed(() => {
  switch (props.status) {
    case 'active':
      return 'bg-g-3 text-g-11';
    case 'draft':
      return 'bg-n-slate-3 text-n-slate-11';
    case 'archived':
      return 'bg-n-amber-3 text-n-amber-11';
    default:
      return 'bg-n-slate-3 text-n-slate-11';
  }
});

const statusLabel = computed(() => {
  switch (props.status) {
    case 'active':
      return t('CAPTAIN_PRODUCTS.FORM.STATUS_ACTIVE');
    case 'draft':
      return t('CAPTAIN_PRODUCTS.FORM.STATUS_DRAFT');
    case 'archived':
      return t('CAPTAIN_PRODUCTS.FORM.STATUS_ARCHIVED');
    default:
      return props.status;
  }
});
</script>

<template>
  <header class="sticky top-0 z-10 bg-n-surface-1 border-b border-n-slate-3">
    <div class="w-full max-w-[72rem] mx-auto px-6 py-4">
      <div
        class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
      >
        <!-- Left: Back + Name + Status -->
        <div class="flex items-center gap-3 min-w-0">
          <button
            class="flex items-center gap-1.5 text-sm text-n-slate-10 hover:text-n-slate-12 shrink-0"
            @click="emit('back')"
          >
            <span class="i-lucide-arrow-left w-4 h-4" />
            {{ t('CAPTAIN_PRODUCTS.DETAIL.BACK_TO_PRODUCTS') }}
          </button>
          <div class="w-px h-5 bg-n-slate-3 shrink-0" />
          <div class="flex items-center gap-2 min-w-0">
            <h1 class="text-lg font-semibold text-n-slate-12 truncate">
              {{ productName }}
            </h1>
            <span
              v-if="isDirty"
              class="w-1.5 h-1.5 rounded-full bg-b-500 shrink-0"
              :aria-label="t('CAPTAIN_PRODUCTS.DETAIL.UNSAVED_DOT_ARIA')"
            />
            <span
              class="inline-flex px-2 py-0.5 rounded text-xs font-medium shrink-0"
              :class="statusBadgeClass"
              :aria-label="`Status: ${statusLabel}`"
            >
              {{ statusLabel }}
            </span>
          </div>
        </div>

        <!-- Right: Actions -->
        <div class="flex items-center gap-2 shrink-0">
          <Button
            v-if="isErpSynced"
            icon="i-lucide-refresh-cw"
            :label="
              isResyncing
                ? t('CAPTAIN_PRODUCTS.DETAIL.RESYNCING')
                : t('CAPTAIN_PRODUCTS.DETAIL.RESYNC')
            "
            color="slate"
            variant="faded"
            size="sm"
            :is-loading="isResyncing"
            :disabled="isResyncing"
            @click="emit('resync')"
          />
          <Button
            :label="t('CAPTAIN_PRODUCTS.DETAIL.DELETE_PRODUCT')"
            color="ruby"
            variant="faded"
            size="sm"
            @click="emit('delete')"
          />
          <Button
            :label="t('CAPTAIN_PRODUCTS.DETAIL.SAVE_CHANGES')"
            size="sm"
            :disabled="!isDirty || !canSave || isSaving"
            :is-loading="isSaving"
            @click="emit('save')"
          />
        </div>
      </div>
    </div>
  </header>
</template>
