<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { vOnClickOutside } from '@vueuse/components';

const props = defineProps({
  conversation: {
    type: Object,
    required: true,
  },
  aiState: {
    type: String,
    required: true,
  },
  copilotMode: {
    type: String,
    default: null,
  },
  pauseMode: {
    type: String,
    default: null,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();

const selectedMode = ref('until_resolved');
const selectedDuration = ref(60);
const isLoading = ref(false);

const isPaused = computed(() => props.aiState === 'paused');

const DURATION_OPTIONS = [
  { label: '30m', value: 30 },
  { label: '1h', value: 60 },
  { label: '2h', value: 120 },
  { label: '4h', value: 240 },
  { label: '8h', value: 480 },
];

const PAUSE_MODES = [
  {
    value: 'permanent',
    labelKey: 'CONVERSATION.HEADER.CAPTAIN_AI.PAUSE_PERMANENT',
    descKey: 'CONVERSATION.HEADER.CAPTAIN_AI.PAUSE_PERMANENT_DESC',
  },
  {
    value: 'until_resolved',
    labelKey: 'CONVERSATION.HEADER.CAPTAIN_AI.PAUSE_UNTIL_RESOLVED',
    descKey: 'CONVERSATION.HEADER.CAPTAIN_AI.PAUSE_UNTIL_RESOLVED_DESC',
  },
  {
    value: 'timed',
    labelKey: 'CONVERSATION.HEADER.CAPTAIN_AI.PAUSE_TIMED',
    descKey: '',
  },
];

const statusText = computed(() => {
  if (props.copilotMode === 'auto_send') {
    return t('CONVERSATION.HEADER.CAPTAIN_AI.STATUS_AUTO_SEND');
  }
  return t('CONVERSATION.HEADER.CAPTAIN_AI.STATUS_DRAFT');
});

const pausedDescription = computed(() => {
  if (props.pauseMode === 'permanent') {
    return t('CONVERSATION.HEADER.CAPTAIN_AI.PAUSED_PERMANENT_DESC');
  }
  if (props.pauseMode === 'until_resolved') {
    return t('CONVERSATION.HEADER.CAPTAIN_AI.PAUSED_UNTIL_RESOLVED_DESC');
  }
  if (props.pauseMode === 'timed') {
    const expiresAt =
      props.conversation.additional_attributes?.pause_expires_at;
    if (expiresAt) {
      const mins = Math.max(
        1,
        Math.ceil((new Date(expiresAt) - new Date()) / 60000)
      );
      return t('CONVERSATION.HEADER.CAPTAIN_AI.PAUSED_TIMED_DESC', {
        time: mins,
      });
    }
    return t('CONVERSATION.HEADER.CAPTAIN_AI.PAUSED_PERMANENT_DESC');
  }
  return '';
});

const restoreModeLabel = computed(() => {
  const mode =
    props.conversation.additional_attributes?.pause_restore_mode || 'draft';
  const modeLabel = mode === 'auto_send' ? 'Auto-send' : 'Draft';
  return t('CONVERSATION.HEADER.CAPTAIN_AI.RESUME_WILL_RESTORE', {
    mode: modeLabel,
  });
});

async function handlePause() {
  isLoading.value = true;
  try {
    await store.dispatch('pauseConversationAi', {
      conversationId: props.conversation.id,
      pauseMode: selectedMode.value,
      pauseDurationMinutes:
        selectedMode.value === 'timed' ? selectedDuration.value : undefined,
    });
    useAlert(t('CONVERSATION.HEADER.CAPTAIN_AI.TOAST_PAUSED'));
    emit('close');
  } catch {
    useAlert(t('CONVERSATION.HEADER.CAPTAIN_AI.TOAST_ERROR'));
  } finally {
    isLoading.value = false;
  }
}

async function handleResume() {
  isLoading.value = true;
  try {
    await store.dispatch('resumeConversationAi', props.conversation.id);
    useAlert(t('CONVERSATION.HEADER.CAPTAIN_AI.TOAST_RESUMED'));
    emit('close');
  } catch {
    useAlert(t('CONVERSATION.HEADER.CAPTAIN_AI.TOAST_ERROR'));
  } finally {
    isLoading.value = false;
  }
}

function handleClickOutside() {
  emit('close');
}

function handleKeydown(event) {
  if (event.key === 'Escape') {
    emit('close');
  }
}
</script>

<template>
  <div
    v-on-click-outside="handleClickOutside"
    class="absolute right-0 top-full mt-1 z-50 w-72 rounded-lg border border-slate-100 dark:border-slate-700 bg-white dark:bg-slate-900 shadow-lg p-4"
    role="dialog"
    :aria-label="t('CONVERSATION.HEADER.CAPTAIN_AI.POPOVER_TITLE')"
    @keydown="handleKeydown"
  >
    <!-- Resume mode (AI is paused) -->
    <template v-if="isPaused">
      <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100">
        {{ t('CONVERSATION.HEADER.CAPTAIN_AI.POPOVER_TITLE') }} —
        {{ t('CONVERSATION.HEADER.CAPTAIN_AI.PAUSED') }}
      </h3>
      <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
        {{ pausedDescription }}
      </p>
      <button
        class="mt-3 w-full h-9 rounded-md bg-woot-500 hover:bg-woot-600 text-white text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-woot-500 focus:ring-offset-1 disabled:opacity-50"
        :disabled="isLoading"
        @click="handleResume"
      >
        <span v-if="isLoading" class="i-lucide-loader-2 size-4 animate-spin" />
        <span v-else>{{
          t('CONVERSATION.HEADER.CAPTAIN_AI.RESUME_BUTTON')
        }}</span>
      </button>
      <p class="mt-2 text-xs text-slate-400 dark:text-slate-500 text-center">
        {{ restoreModeLabel }}
      </p>
    </template>

    <!-- Pause mode (AI is active) -->
    <template v-else>
      <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100">
        {{ t('CONVERSATION.HEADER.CAPTAIN_AI.POPOVER_TITLE') }}
      </h3>
      <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
        {{ statusText }}
      </p>

      <div class="mt-3 flex flex-col gap-2" role="radiogroup">
        <label
          v-for="mode in PAUSE_MODES"
          :key="mode.value"
          class="flex items-start gap-2 cursor-pointer group"
        >
          <input
            v-model="selectedMode"
            type="radio"
            name="pause-mode"
            :value="mode.value"
            class="mt-0.5 accent-woot-500"
          />
          <div class="flex-1 min-w-0">
            <span
              class="text-sm text-slate-800 dark:text-slate-200 font-medium"
            >
              {{ t(mode.labelKey) }}
            </span>
            <p
              v-if="mode.descKey"
              class="text-xs text-slate-400 dark:text-slate-500 mt-0.5"
            >
              {{ t(mode.descKey) }}
            </p>
            <!-- Duration chips for timed mode -->
            <div
              v-if="mode.value === 'timed' && selectedMode === 'timed'"
              class="flex gap-1.5 mt-2"
            >
              <button
                v-for="opt in DURATION_OPTIONS"
                :key="opt.value"
                type="button"
                class="h-7 px-2.5 rounded-md text-xs font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-woot-500"
                :class="
                  selectedDuration === opt.value
                    ? 'bg-woot-500 text-white'
                    : 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700'
                "
                @click="selectedDuration = opt.value"
              >
                {{ opt.label }}
              </button>
            </div>
          </div>
        </label>
      </div>

      <button
        class="mt-4 w-full h-9 rounded-md bg-red-500 hover:bg-red-600 text-white text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-1 disabled:opacity-50"
        :disabled="isLoading"
        @click="handlePause"
      >
        <span v-if="isLoading" class="i-lucide-loader-2 size-4 animate-spin" />
        <span v-else>{{
          t('CONVERSATION.HEADER.CAPTAIN_AI.PAUSE_BUTTON')
        }}</span>
      </button>
    </template>
  </div>
</template>
