<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  label: { type: String, required: true },
  enabled: { type: Boolean, default: true },
  locked: { type: Boolean, default: false },
  canMoveUp: { type: Boolean, default: false },
  canMoveDown: { type: Boolean, default: false },
});

const emit = defineEmits(['update:enabled', 'move-up', 'move-down']);
const { t } = useI18n();

const expanded = ref(props.enabled);

const toggleEnabled = () => {
  emit('update:enabled', !props.enabled);
};

const toggleExpanded = () => {
  if (props.enabled) {
    expanded.value = !expanded.value;
  }
};
</script>

<template>
  <div class="border-b border-n-weak last:border-b-0">
    <!-- Section header row -->
    <div
      class="flex items-center justify-between px-4 py-3.5 cursor-pointer"
      @click="toggleExpanded"
    >
      <div class="flex items-center gap-3">
        <!-- Locked sections show a static enabled indicator -->
        <div
          v-if="locked"
          class="relative h-4 w-7 rounded-full bg-n-brand flex-shrink-0 opacity-60 cursor-not-allowed"
          @click.stop
        >
          <span
            class="absolute top-0.5 left-0.5 h-3 w-3 translate-x-3 rounded-full bg-n-background shadow-sm"
          />
        </div>
        <span v-else @click.stop>
          <Switch :model-value="enabled" @change="toggleEnabled" />
        </span>
        <span
          class="text-sm font-medium"
          :class="enabled ? 'text-n-slate-12' : 'text-n-slate-9'"
        >
          {{ label }}
          <span v-if="locked" class="text-xs text-n-slate-8 ml-1">
            {{ t('CARD_DESIGNS.REQUIRED_HINT') }}
          </span>
        </span>
      </div>

      <div class="flex items-center gap-2">
        <!-- Move up/down arrows -->
        <div
          v-if="canMoveUp || canMoveDown"
          class="flex items-center gap-1.5"
          @click.stop
        >
          <button
            :disabled="!canMoveUp"
            class="w-8 h-8 flex items-center justify-center rounded-lg border border-n-weak bg-n-solid-1 hover:bg-n-alpha-2 active:bg-n-alpha-3 disabled:opacity-20 disabled:cursor-not-allowed transition-colors shadow-sm"
            :title="t('CARD_DESIGNS.MOVE_UP')"
            @click="emit('move-up')"
          >
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="text-n-slate-12"
            >
              <path d="m18 15-6-6-6 6" />
            </svg>
          </button>
          <button
            :disabled="!canMoveDown"
            class="w-8 h-8 flex items-center justify-center rounded-lg border border-n-weak bg-n-solid-1 hover:bg-n-alpha-2 active:bg-n-alpha-3 disabled:opacity-20 disabled:cursor-not-allowed transition-colors shadow-sm"
            :title="t('CARD_DESIGNS.MOVE_DOWN')"
            @click="emit('move-down')"
          >
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="text-n-slate-12"
            >
              <path d="m6 9 6 6 6-6" />
            </svg>
          </button>
        </div>

        <!-- Expand/collapse chevron -->
        <svg
          v-if="enabled"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="text-n-slate-9 transition-transform"
        >
          <path v-if="expanded" d="m18 15-6-6-6 6" />
          <path v-else d="m6 9 6 6 6-6" />
        </svg>
      </div>
    </div>

    <!-- Expanded controls -->
    <div v-if="enabled && expanded" class="px-4 pb-4 pl-14 space-y-3">
      <slot />
    </div>
  </div>
</template>
