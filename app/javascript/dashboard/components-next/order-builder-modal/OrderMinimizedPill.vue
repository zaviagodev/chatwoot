<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  itemCount: { type: Number, default: 0 },
});

defineEmits(['restore']);

const { t } = useI18n();
const I18N = 'CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL';

const pillLabel = computed(() =>
  t(`${I18N}.PILL_LABEL`, { count: props.itemCount })
);

const pillText = computed(() =>
  props.itemCount === 1
    ? t(`${I18N}.PILL_ITEM_SINGULAR`, { count: props.itemCount })
    : t(`${I18N}.PILL_ITEMS`, { count: props.itemCount })
);
</script>

<template>
  <Transition
    enter-active-class="transition-all duration-200 ease-out"
    enter-from-class="scale-75 opacity-0"
    enter-to-class="scale-100 opacity-100"
    leave-active-class="transition-all duration-150 ease-in"
    leave-from-class="scale-100 opacity-100"
    leave-to-class="scale-75 opacity-0"
  >
    <button
      v-if="itemCount > 0"
      class="fixed bottom-20 right-4 z-[9998] flex items-center gap-2 rounded-full bg-n-blue-9 px-4 py-2.5 text-white shadow-lg transition-transform hover:scale-105"
      :aria-label="pillLabel"
      role="button"
      @click="$emit('restore')"
    >
      <!-- Pulsing dot -->
      <span class="relative flex h-2 w-2">
        <span
          class="absolute inline-flex h-full w-full animate-ping rounded-full bg-n-green-9 opacity-75"
        />
        <span class="relative inline-flex h-2 w-2 rounded-full bg-n-green-9" />
      </span>
      <Icon icon="i-lucide-shopping-cart" size="16" />
      <span class="text-sm font-semibold">{{ pillText }}</span>
    </button>
  </Transition>
</template>
