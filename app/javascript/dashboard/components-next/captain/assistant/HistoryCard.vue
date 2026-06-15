<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import CardLayout from 'dashboard/components-next/CardLayout.vue';

const props = defineProps({
  content: { type: String, default: '' },
  conversationDisplayId: { type: Number, default: null },
  createdAt: { type: String, default: '' },
  approvedBy: { type: String, default: '' },
  edited: { type: Boolean, default: false },
  model: { type: String, default: '' },
  inputTokens: { type: Number, default: null },
  outputTokens: { type: Number, default: null },
});

const { t } = useI18n();

const truncatedContent = computed(() => {
  if (!props.content) return '';
  return props.content.length > 200
    ? props.content.slice(0, 200) + '...'
    : props.content;
});

const formattedDate = computed(() => {
  if (!props.createdAt) return '';
  const date = new Date(props.createdAt);
  return date.toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
});

const tokenDisplay = computed(() => {
  if (props.inputTokens == null && props.outputTokens == null) return '';
  return t('CAPTAIN_HISTORY.CARD.TOKENS', {
    input: props.inputTokens ?? 0,
    output: props.outputTokens ?? 0,
  });
});
</script>

<template>
  <CardLayout>
    <div class="flex flex-col gap-2 p-4">
      <!-- Header row: conversation link + date -->
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <span
            v-if="conversationDisplayId"
            class="inline-flex items-center gap-1 text-xs font-medium px-1.5 py-0.5 rounded bg-b-50 text-b-600 dark:bg-b-900 dark:text-b-300"
          >
            <span class="i-lucide-message-square text-xs" />
            {{
              t('CAPTAIN_HISTORY.CARD.CONVERSATION', {
                id: conversationDisplayId,
              })
            }}
          </span>
          <span
            v-if="edited"
            class="text-xs px-1.5 py-0.5 rounded bg-n-alpha-2 text-n-slate-11"
          >
            {{ t('CAPTAIN_HISTORY.CARD.EDITED') }}
          </span>
        </div>
        <span class="text-xs text-n-slate-9 shrink-0">
          {{ formattedDate }}
        </span>
      </div>

      <!-- Response content -->
      <p class="text-sm text-n-slate-12 leading-relaxed">
        {{ truncatedContent }}
      </p>

      <!-- Footer: metadata -->
      <div class="flex items-center gap-3 text-xs text-n-slate-9">
        <span v-if="approvedBy" class="flex items-center gap-1">
          <span class="i-lucide-check-circle text-xs text-n-green-9" />
          {{ t('CAPTAIN_HISTORY.CARD.APPROVED_BY', { name: approvedBy }) }}
        </span>
        <span v-if="model" class="flex items-center gap-1">
          <span class="i-lucide-cpu text-xs" />
          {{ model }}
        </span>
        <span v-if="tokenDisplay" class="flex items-center gap-1">
          <span class="i-lucide-hash text-xs" />
          {{ tokenDisplay }}
        </span>
      </div>
    </div>
  </CardLayout>
</template>
