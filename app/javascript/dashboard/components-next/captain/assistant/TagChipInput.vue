<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => [],
  },
  placeholder: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();
const inputValue = ref('');

const addTag = () => {
  const tag = inputValue.value.trim();
  if (tag && !props.modelValue.includes(tag)) {
    emit('update:modelValue', [...props.modelValue, tag]);
  }
  inputValue.value = '';
};

const removeTag = index => {
  const updated = [...props.modelValue];
  updated.splice(index, 1);
  emit('update:modelValue', updated);
};

const handleKeydown = event => {
  if (event.key === 'Enter') {
    event.preventDefault();
    addTag();
  } else if (
    event.key === 'Backspace' &&
    !inputValue.value &&
    props.modelValue.length
  ) {
    removeTag(props.modelValue.length - 1);
  }
};
</script>

<template>
  <div
    class="flex flex-wrap items-center gap-1.5 px-3 py-2 border rounded-lg border-n-slate-5 bg-n-surface-1 focus-within:border-b-500 focus-within:ring-1 focus-within:ring-b-500 min-h-[38px]"
  >
    <span
      v-for="(tag, index) in modelValue"
      :key="tag"
      class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md bg-n-slate-3 text-sm text-n-slate-12"
    >
      {{ tag }}
      <button
        type="button"
        class="text-n-slate-8 hover:text-n-slate-12"
        :aria-label="t('CAPTAIN_REVIEWS.DRAWER.REMOVE_TAG', { tag })"
        @click="removeTag(index)"
      >
        <span class="i-lucide-x text-xs" />
      </button>
    </span>
    <input
      v-model="inputValue"
      type="text"
      class="flex-1 min-w-[80px] text-sm bg-transparent outline-none text-n-slate-12 placeholder:text-n-slate-8"
      :placeholder="modelValue.length ? '' : placeholder"
      @keydown="handleKeydown"
      @blur="addTag"
    />
  </div>
</template>
