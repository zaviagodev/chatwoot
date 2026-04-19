<script setup>
import { computed } from 'vue';

const props = defineProps({
  field: { type: Object, required: true },
  modelValue: { type: String, default: '' },
  error: { type: String, default: '' },
  isRequired: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);

const options = computed(() => {
  const raw = props.field.options || '';
  return raw
    .split(/[,\n]/)
    .map(o => o.trim())
    .filter(Boolean);
});
</script>

<template>
  <div class="personalization-field">
    <label class="personalization-field-label">
      {{ field.label }}
      <span v-if="isRequired" class="personalization-field-required">*</span>
      <span v-if="field.addon_price" class="personalization-field-addon">
        (+{{ field.addon_price }})
      </span>
    </label>
    <select
      :value="modelValue"
      :aria-required="isRequired"
      class="personalization-field-select"
      :class="{ 'personalization-field-select--error': error }"
      @change="emit('update:modelValue', $event.target.value)"
    >
      <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
      <option value="">Select...</option>
      <option v-for="opt in options" :key="opt" :value="opt">
        {{ opt }}
      </option>
    </select>
    <span v-if="error" class="personalization-field-error">{{ error }}</span>
  </div>
</template>

<style scoped>
.personalization-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.personalization-field-label {
  font-size: 12px;
  font-weight: 500;
  color: var(--s-700);
}
.personalization-field-required {
  color: var(--r-500);
  margin-left: 2px;
}
.personalization-field-addon {
  color: var(--s-500);
  font-size: 11px;
  font-weight: 400;
  margin-left: 4px;
}
.personalization-field-select {
  width: 100%;
  height: 34px;
  padding: 0 10px;
  border: 1px solid var(--s-200);
  border-radius: var(--border-radius-small);
  font-size: 13px;
  color: var(--s-900);
  background: var(--white);
  appearance: auto;
}
.personalization-field-select:focus {
  outline: none;
  border-color: var(--w-500);
  box-shadow: 0 0 0 2px var(--w-100);
}
.personalization-field-select--error {
  border-color: var(--r-500);
}
.personalization-field-error {
  font-size: 11px;
  color: var(--r-500);
}
</style>
