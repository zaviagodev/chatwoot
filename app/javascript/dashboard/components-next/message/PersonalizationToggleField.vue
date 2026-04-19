<script setup>
const props = defineProps({
  field: { type: Object, required: true },
  modelValue: { type: String, default: '' },
  error: { type: String, default: '' },
  isRequired: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);

const toggle = () => {
  emit('update:modelValue', props.modelValue === '1' ? '' : '1');
};
</script>

<template>
  <div class="personalization-toggle">
    <div class="personalization-toggle-row" @click="toggle">
      <span class="personalization-toggle-label">
        {{ field.label }}
        <span v-if="isRequired" class="personalization-toggle-required">*</span>
        <span v-if="field.addon_price" class="personalization-toggle-addon">
          (+{{ field.addon_price }})
        </span>
      </span>
      <button
        type="button"
        role="switch"
        :aria-checked="modelValue === '1'"
        :aria-label="field.label"
        class="personalization-toggle-switch"
        :class="{ 'personalization-toggle-switch--on': modelValue === '1' }"
        @click.stop="toggle"
      >
        <span class="personalization-toggle-thumb" />
      </button>
    </div>
    <span v-if="error" class="personalization-toggle-error">{{ error }}</span>
  </div>
</template>

<style scoped>
.personalization-toggle {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.personalization-toggle-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  cursor: pointer;
  padding: 4px 0;
}
.personalization-toggle-label {
  font-size: 12px;
  font-weight: 500;
  color: var(--s-700);
}
.personalization-toggle-required {
  color: var(--r-500);
  margin-left: 2px;
}
.personalization-toggle-addon {
  color: var(--s-500);
  font-size: 11px;
  font-weight: 400;
  margin-left: 4px;
}
.personalization-toggle-switch {
  position: relative;
  width: 36px;
  height: 20px;
  border-radius: 10px;
  background: var(--s-200);
  border: none;
  cursor: pointer;
  transition: background 0.2s;
  flex-shrink: 0;
}
.personalization-toggle-switch--on {
  background: var(--w-500);
}
.personalization-toggle-thumb {
  position: absolute;
  top: 2px;
  left: 2px;
  width: 16px;
  height: 16px;
  border-radius: 50%;
  background: var(--white);
  transition: transform 0.2s;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.15);
}
.personalization-toggle-switch--on .personalization-toggle-thumb {
  transform: translateX(16px);
}
.personalization-toggle-error {
  font-size: 11px;
  color: var(--r-500);
}
</style>
