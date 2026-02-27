<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import CaptainProducts from 'dashboard/api/captain/products';

const props = defineProps({
  modelValue: { type: [Number, null], default: null },
  assistantId: { type: Number, required: true },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

const products = ref([]);
const isLoading = ref(false);
const hasError = ref(false);

const hasProducts = computed(() => products.value.length > 0);
const isDisabled = computed(
  () => props.disabled || isLoading.value || !hasProducts.value
);

const placeholderText = computed(() => {
  if (isLoading.value) return '...';
  if (!hasProducts.value)
    return t('CAPTAIN_REVIEWS.DRAWER.PRODUCT_LINK_NO_PRODUCTS');
  return t('CAPTAIN_REVIEWS.DRAWER.PRODUCT_LINK_PLACEHOLDER');
});

const fetchProducts = async () => {
  isLoading.value = true;
  hasError.value = false;
  try {
    const { data } = await CaptainProducts.get({
      assistantId: props.assistantId,
    });
    products.value = data.payload || [];
  } catch {
    hasError.value = true;
    products.value = [];
  }
  isLoading.value = false;
};

const handleChange = event => {
  const val = event.target.value;
  emit('update:modelValue', val ? Number(val) : null);
};

onMounted(fetchProducts);

watch(() => props.assistantId, fetchProducts);
</script>

<template>
  <select
    :value="modelValue || ''"
    :disabled="isDisabled"
    class="w-full px-3 py-2 text-sm border rounded-lg bg-n-alpha-1 border-n-weak text-n-slate-12 disabled:opacity-50 disabled:cursor-not-allowed"
    @change="handleChange"
  >
    <option value="">
      {{ placeholderText }}
    </option>
    <option v-for="product in products" :key="product.id" :value="product.id">
      {{ product.item_name }}
    </option>
  </select>
</template>
