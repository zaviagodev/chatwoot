<script setup>
const props = defineProps({
  field: { type: Object, required: true },
  modelValue: { type: String, default: '' },
  error: { type: String, default: '' },
  isRequired: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);

const charCount = () => {
  if (!props.field.max_characters) return '';
  return `${(props.modelValue || '').length}/${props.field.max_characters}`;
};

const isAtLimit = () => {
  return (
    props.field.max_characters &&
    (props.modelValue || '').length >= props.field.max_characters
  );
};
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
    <input
      type="text"
      :value="modelValue"
      :maxlength="field.max_characters || undefined"
      :placeholder="field.placeholder || ''"
      :aria-required="isRequired"
      class="personalization-field-input"
      :class="{ 'personalization-field-input--error': error }"
      @input="emit('update:modelValue', $event.target.value)"
    />
    <div class="personalization-field-meta">
      <span v-if="error" class="personalization-field-error">{{ error }}</span>
      <span
        v-if="charCount()"
        class="personalization-field-charcount"
        :class="{ 'personalization-field-charcount--limit': isAtLimit() }"
      >
        {{ charCount() }}
      </span>
    </div>
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
.personalization-field-input {
  width: 100%;
  height: 34px;
  padding: 0 10px;
  border: 1px solid var(--s-200);
  border-radius: var(--border-radius-small);
  font-size: 13px;
  color: var(--s-900);
  background: var(--white);
}
.personalization-field-input:focus {
  outline: none;
  border-color: var(--w-500);
  box-shadow: 0 0 0 2px var(--w-100);
}
.personalization-field-input--error {
  border-color: var(--r-500);
}
.personalization-field-meta {
  display: flex;
  justify-content: space-between;
  min-height: 16px;
}
.personalization-field-error {
  font-size: 11px;
  color: var(--r-500);
}
.personalization-field-charcount {
  font-size: 11px;
  color: var(--s-500);
  margin-left: auto;
}
.personalization-field-charcount--limit {
  color: var(--r-500);
}
</style>
