<script setup>
import ColorPicker from 'dashboard/components-next/colorpicker/ColorPicker.vue';

defineProps({
  label: { type: String, required: true },
  modelValue: { type: String, default: '#000000' },
});

const emit = defineEmits(['update:modelValue']);

const updateColor = value => {
  emit('update:modelValue', value);
};
</script>

<template>
  <div class="flex items-center justify-between">
    <span class="text-sm text-n-slate-12">{{ label }}</span>
    <ColorPicker :model-value="modelValue" @update:model-value="updateColor" />
  </div>
</template>
