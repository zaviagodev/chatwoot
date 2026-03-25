<script setup>
import { useI18n } from 'vue-i18n';
import Icon from 'next/icon/Icon.vue';

defineProps({
  currentStep: { type: Number, default: 1 },
  completedSteps: { type: Array, default: () => [] },
  cartItemCount: { type: Number, default: 0 },
});

defineEmits(['stepClick']);

const { t } = useI18n();

const steps = [
  { id: 1, label: 'CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.STEP_PRODUCTS' },
  { id: 2, label: 'CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.STEP_DELIVERY' },
  { id: 3, label: 'CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.STEP_REVIEW' },
];
</script>

<template>
  <nav
    class="flex items-center gap-2 px-4 py-3"
    :aria-label="t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.ORDER_STEPS')"
  >
    <template v-for="(step, index) in steps" :key="step.id">
      <!-- Connecting line -->
      <div
        v-if="index > 0"
        class="h-px flex-1"
        :class="
          completedSteps.includes(step.id) || currentStep >= step.id
            ? 'bg-n-blue-9'
            : 'bg-n-slate-6'
        "
      />

      <!-- Step circle + label -->
      <button
        class="flex items-center gap-2 text-sm font-medium transition-colors"
        :class="{
          'cursor-pointer': completedSteps.includes(step.id),
          'cursor-default': !completedSteps.includes(step.id),
        }"
        :disabled="!completedSteps.includes(step.id) && currentStep !== step.id"
        :aria-current="currentStep === step.id ? 'step' : undefined"
        @click="completedSteps.includes(step.id) && $emit('stepClick', step.id)"
      >
        <!-- Circle -->
        <span
          class="flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs font-semibold transition-colors"
          :class="{
            'bg-n-blue-9 text-white': currentStep === step.id,
            'bg-n-blue-9 text-white':
              completedSteps.includes(step.id) && currentStep !== step.id,
            'border border-n-slate-6 bg-n-slate-3 text-n-slate-9':
              !completedSteps.includes(step.id) && currentStep !== step.id,
          }"
        >
          <Icon
            v-if="completedSteps.includes(step.id) && currentStep !== step.id"
            icon="i-lucide-check"
            size="14"
          />
          <span v-else>{{ step.id }}</span>
        </span>

        <!-- Label -->
        <span
          :class="{
            'text-n-slate-12': currentStep === step.id,
            'text-n-blue-11': completedSteps.includes(step.id),
            'text-n-slate-9':
              !completedSteps.includes(step.id) && currentStep !== step.id,
          }"
        >
          {{ t(step.label) }}
        </span>

        <!-- Cart item count badge on step 1 -->
        <span
          v-if="step.id === 1 && cartItemCount > 0"
          class="ml-1 flex h-5 min-w-[20px] items-center justify-center rounded-full bg-n-blue-9 px-1.5 text-xs font-semibold text-white"
        >
          {{ cartItemCount }}
        </span>
      </button>
    </template>
  </nav>
</template>
