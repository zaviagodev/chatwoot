<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: {
    type: Number,
    default: 0,
  },
});
const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();
const stars = computed(() => Array.from({ length: 5 }, (_, i) => i + 1));

const setRating = value => {
  emit('update:modelValue', value === props.modelValue ? 0 : value);
};
</script>

<template>
  <div
    class="flex gap-1"
    role="radiogroup"
    :aria-label="t('CAPTAIN_REVIEWS.RATING')"
  >
    <button
      v-for="star in stars"
      :key="star"
      type="button"
      class="p-0.5 text-xl transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-n-blue-7 rounded"
      :class="
        star <= modelValue
          ? 'text-yellow-400'
          : 'text-n-slate-6 hover:text-yellow-300'
      "
      :aria-label="`${star} star${star > 1 ? 's' : ''}`"
      :aria-checked="star === modelValue"
      role="radio"
      @click="setRating(star)"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        :fill="star <= modelValue ? 'currentColor' : 'none'"
        stroke="currentColor"
        stroke-width="1.5"
        class="size-5"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M11.48 3.499a.562.562 0 0 1 1.04 0l2.125 5.111a.563.563 0 0 0 .475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 0 0-.182.557l1.285 5.385a.562.562 0 0 1-.84.61l-4.725-2.885a.562.562 0 0 0-.586 0L6.982 20.54a.562.562 0 0 1-.84-.61l1.285-5.386a.562.562 0 0 0-.182-.557l-4.204-3.602a.562.562 0 0 1 .321-.988l5.518-.442a.563.563 0 0 0 .475-.345L11.48 3.5Z"
        />
      </svg>
    </button>
  </div>
</template>
