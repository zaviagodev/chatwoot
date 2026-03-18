<script setup>
import { computed, ref, onMounted, onUnmounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import CaptainAiPausePopover from './CaptainAiPausePopover.vue';

const props = defineProps({
  conversation: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const store = useStore();
const showPopover = ref(false);

const copilotAssistant = computed(() => store.getters.getCopilotAssistant);

const copilotMode = computed(() => {
  return props.conversation.additional_attributes?.copilot_mode || null;
});

const pauseMode = computed(() => {
  return props.conversation.additional_attributes?.pause_mode || null;
});

// Show indicator only when Captain AI is configured on this inbox
const hasCaptainAi = computed(() => {
  return !!copilotMode.value || !!copilotAssistant.value?.id;
});

const isPaused = computed(
  () => copilotMode.value === 'off' && !!pauseMode.value
);

const aiState = computed(() => {
  if (isPaused.value) return 'paused';
  if (copilotMode.value === 'auto_send') return 'auto_send';
  if (copilotMode.value === 'draft') return 'draft';
  return null;
});

const PILL_CONFIG = {
  auto_send: {
    icon: 'i-lucide-sparkles',
    classes: 'bg-teal-50 text-teal-700 dark:bg-teal-900/30 dark:text-teal-300',
    tooltip: 'CONVERSATION.HEADER.CAPTAIN_AI.TOOLTIP_AUTO_SEND',
  },
  draft: {
    icon: 'i-lucide-pencil',
    classes: 'bg-blue-50 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300',
    tooltip: 'CONVERSATION.HEADER.CAPTAIN_AI.TOOLTIP_DRAFT',
  },
  paused: {
    icon: 'i-lucide-circle-pause',
    classes:
      'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400',
    tooltip: 'CONVERSATION.HEADER.CAPTAIN_AI.TOOLTIP_PAUSED',
  },
};

const config = computed(() => PILL_CONFIG[aiState.value] || PILL_CONFIG.draft);

const LABEL_MAP = {
  auto_send: 'CONVERSATION.HEADER.CAPTAIN_AI.AUTO_SEND',
  draft: 'CONVERSATION.HEADER.CAPTAIN_AI.DRAFT',
  paused: 'CONVERSATION.HEADER.CAPTAIN_AI.PAUSED',
};

const pillLabel = computed(() => {
  const key = LABEL_MAP[aiState.value] || LABEL_MAP.draft;
  return t(key);
});

// Countdown timer for timed pause
const remainingMinutes = ref(null);
let countdownInterval = null;

function computeRemaining() {
  const expiresAt = props.conversation.additional_attributes?.pause_expires_at;
  if (!expiresAt || pauseMode.value !== 'timed') {
    remainingMinutes.value = null;
    return;
  }
  const diffMs = new Date(expiresAt) - new Date();
  if (diffMs <= 0) {
    remainingMinutes.value = 0;
    return;
  }
  remainingMinutes.value = Math.floor(diffMs / 60000);
}

onMounted(() => {
  computeRemaining();
  countdownInterval = setInterval(computeRemaining, 60000);
});

onUnmounted(() => {
  if (countdownInterval) clearInterval(countdownInterval);
});

watch(
  () => props.conversation.additional_attributes?.pause_expires_at,
  () => computeRemaining()
);

const countdownSuffix = computed(() => {
  if (
    !isPaused.value ||
    pauseMode.value !== 'timed' ||
    remainingMinutes.value === null
  )
    return '';
  if (remainingMinutes.value <= 0) return '<1m';
  return `${remainingMinutes.value}m`;
});

const tooltipText = computed(() => {
  if (
    isPaused.value &&
    pauseMode.value === 'timed' &&
    remainingMinutes.value !== null &&
    remainingMinutes.value >= 0
  ) {
    const time =
      remainingMinutes.value <= 0 ? '<1m' : `${remainingMinutes.value}m`;
    return t('CONVERSATION.HEADER.CAPTAIN_AI.TOOLTIP_PAUSED_TIMED', { time });
  }
  return t(config.value.tooltip);
});

function togglePopover() {
  showPopover.value = !showPopover.value;
}

function closePopover() {
  showPopover.value = false;
}
</script>

<template>
  <div v-if="hasCaptainAi && aiState" class="relative">
    <button
      v-tooltip="tooltipText"
      class="h-7 px-2 rounded-md flex items-center gap-1 cursor-pointer transition-colors duration-150 focus:outline-none focus:ring-2 focus:ring-woot-500"
      :class="config.classes"
      :aria-label="tooltipText"
      @click="togglePopover"
      @keydown.escape="closePopover"
    >
      <span class="size-3" :class="[config.icon]" />
      <span class="text-xs font-semibold">{{ pillLabel }}</span>
      <span v-if="countdownSuffix" class="text-xs font-semibold ml-0.5">{{
        countdownSuffix
      }}</span>
    </button>
    <CaptainAiPausePopover
      v-if="showPopover"
      :conversation="conversation"
      :ai-state="aiState"
      :copilot-mode="copilotMode"
      :pause-mode="pauseMode"
      @close="closePopover"
    />
  </div>
</template>
