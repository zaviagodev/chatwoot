<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  events: {
    type: Array,
    default: () => [],
  },
  state: {
    type: String,
    default: 'idle',
  },
  elapsedDisplay: {
    type: String,
    default: '0.0',
  },
  errorMessage: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();

const elapsedLabel = computed(() => `${props.elapsedDisplay}s`);

const startTimestamp = computed(() =>
  props.events.length > 0 ? props.events[0].timestamp : 0
);

const relativeTimeLabel = timestamp => {
  if (!startTimestamp.value) return '';
  const seconds = ((timestamp - startTimestamp.value) / 1000).toFixed(1);
  return `+${seconds}s`;
};

const isActiveStep = index => {
  return (
    index === props.events.length - 1 &&
    (props.state === 'debouncing' || props.state === 'generating')
  );
};

const errorText = computed(
  () => props.errorMessage || t('CAPTAIN.COPILOT.THINKING.GENERATION_FAILED')
);
</script>

<template>
  <li class="flex justify-center my-2">
    <div
      class="max-w-[280px] w-full rounded-xl bg-n-iris-2 dark:bg-n-iris-3 border border-n-iris-4 px-4 py-3 shadow-sm"
    >
      <!-- Header -->
      <div class="flex items-center gap-2 mb-2">
        <span class="i-lucide-sparkles size-3.5 text-n-iris-10" />
        <span class="text-xs font-semibold text-n-iris-11">
          {{ t('CAPTAIN.NAME') }}
        </span>
        <span class="text-xs text-n-slate-10 tabular-nums ml-auto">
          {{ elapsedLabel }}
        </span>
      </div>
      <!-- Timeline steps -->
      <div class="flex flex-col gap-1.5">
        <div
          v-for="(event, index) in events"
          :key="event.timestamp"
          class="flex items-center gap-2 text-xs"
        >
          <!-- Active step: bouncing dots -->
          <span
            v-if="isActiveStep(index)"
            class="flex gap-0.5 w-3.5 justify-center"
          >
            <span
              class="size-1 rounded-full bg-n-iris-9 animate-bounce [animation-delay:-0.2s]"
            />
            <span
              class="size-1 rounded-full bg-n-iris-9 animate-bounce [animation-delay:-0.1s]"
            />
            <span class="size-1 rounded-full bg-n-iris-9 animate-bounce" />
          </span>
          <!-- Completed step: checkmark -->
          <span v-else class="i-lucide-check size-3.5 text-n-green-9" />
          <!-- Step label -->
          <span
            :class="
              isActiveStep(index)
                ? 'text-n-iris-11 font-medium'
                : 'text-n-slate-10'
            "
          >
            {{ event.label }}
          </span>
          <!-- Relative time -->
          <span class="text-n-slate-9 ml-auto tabular-nums">
            {{ relativeTimeLabel(event.timestamp) }}
          </span>
        </div>
      </div>
      <!-- Error state -->
      <div
        v-if="state === 'error'"
        class="flex items-center gap-2 text-xs mt-1.5 text-n-ruby-10"
      >
        <span class="i-lucide-alert-triangle size-3.5" />
        <span>{{ errorText }}</span>
      </div>
    </div>
  </li>
</template>
