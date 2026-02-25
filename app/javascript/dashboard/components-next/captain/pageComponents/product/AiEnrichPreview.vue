<script setup>
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  product: {
    type: Object,
    required: true,
  },
  enrichedText: {
    type: String,
    default: '',
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  hasError: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['approve', 'edit', 'discard', 'retry']);
const { t } = useI18n();

const handleApprove = () => {
  emit('approve', props.enrichedText);
};

const handleEdit = () => {
  emit('edit', props.enrichedText);
};
</script>

<template>
  <div class="p-4 ml-2 rounded-lg border border-n-weak bg-n-alpha-1">
    <!-- Loading state -->
    <div v-if="isLoading" class="flex flex-col gap-3">
      <span class="text-xs font-medium text-n-slate-11">
        {{ t('CAPTAIN_PRODUCTS.AI_ENRICH.GENERATING') }}
      </span>
      <div class="flex flex-col gap-2">
        <div class="h-3 rounded bg-n-alpha-2 animate-pulse w-full" />
        <div class="h-3 rounded bg-n-alpha-2 animate-pulse w-4/5" />
        <div class="h-3 rounded bg-n-alpha-2 animate-pulse w-3/5" />
      </div>
    </div>

    <!-- Error state -->
    <div v-else-if="hasError" class="flex flex-col gap-3">
      <p class="text-sm text-n-slate-11">
        {{ t('CAPTAIN_PRODUCTS.AI_ENRICH.ERROR') }}
      </p>
      <div class="flex gap-2">
        <Button
          size="xs"
          :label="t('CAPTAIN_PRODUCTS.AI_ENRICH.RETRY')"
          icon="i-lucide-refresh-cw"
          @click="$emit('retry')"
        />
        <Button
          size="xs"
          variant="faded"
          color="slate"
          :label="t('CAPTAIN_PRODUCTS.AI_ENRICH.WRITE_MANUALLY')"
          @click="handleEdit"
        />
      </div>
    </div>

    <!-- Preview state -->
    <div v-else class="flex flex-col gap-4">
      <!-- Enriched text -->
      <div>
        <span class="text-xs font-medium text-n-slate-11 mb-2 block">
          {{ t('CAPTAIN_PRODUCTS.AI_ENRICH.PREVIEW_TITLE') }}
        </span>
        <div
          class="p-3 text-sm rounded-lg border border-b-200 bg-b-50 text-n-slate-12 dark:bg-b-900/10 dark:border-b-800 whitespace-pre-wrap"
        >
          {{ enrichedText }}
        </div>
      </div>

      <!-- Current description for comparison -->
      <div v-if="product.formatted_text">
        <span class="text-xs font-medium text-n-slate-10 mb-2 block">
          {{ t('CAPTAIN_PRODUCTS.AI_ENRICH.CURRENT_TITLE') }}
        </span>
        <div
          class="p-3 text-xs rounded-lg bg-n-alpha-1 text-n-slate-10 whitespace-pre-wrap"
        >
          {{ product.formatted_text }}
        </div>
      </div>

      <!-- Action buttons -->
      <div class="flex gap-2 items-center">
        <Button
          size="xs"
          :label="t('CAPTAIN_PRODUCTS.AI_ENRICH.USE_THIS')"
          @click="handleApprove"
        />
        <Button
          size="xs"
          variant="faded"
          color="slate"
          :label="t('CAPTAIN_PRODUCTS.AI_ENRICH.EDIT_AND_USE')"
          @click="handleEdit"
        />
        <button
          class="text-xs text-n-slate-10 hover:text-n-slate-12 ml-2"
          @click="$emit('discard')"
        >
          {{ t('CAPTAIN_PRODUCTS.AI_ENRICH.DISCARD') }}
        </button>
      </div>
    </div>
  </div>
</template>
