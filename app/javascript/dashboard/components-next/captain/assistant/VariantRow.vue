<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  variant: {
    type: Object,
    required: true,
  },
  currency: {
    type: String,
    default: 'THB',
  },
  parentPrice: {
    type: Number,
    default: 0,
  },
});

const emit = defineEmits(['toggle']);
const { t } = useI18n();

const isEnabled = computed(() => props.variant.enabled !== false);

const attributes = computed(() => {
  const attrs = props.variant.attributes || [];
  if (!attrs.length) return '';
  return attrs.map(a => `${a.attribute}: ${a.value}`).join(' · ');
});

const displayPrice = computed(() => {
  const price =
    props.variant.price_override ?? props.variant.price ?? props.parentPrice;
  if (!price || price <= 0) return '';
  const formatted = Number(price).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return `${props.currency} ${formatted}`;
});

const hasOverride = computed(() => props.variant.price_override != null);

const stockQty = computed(() => props.variant.stock_qty ?? 0);
const inStock = computed(() => stockQty.value > 0);

const stockLabel = computed(() => {
  if (inStock.value) {
    return `${t('CAPTAIN_PRODUCTS.CARD.IN_STOCK')} (${stockQty.value})`;
  }
  return t('CAPTAIN_PRODUCTS.CARD.OUT_OF_STOCK');
});

const stockDotColor = computed(() => (inStock.value ? 'bg-g-400' : 'bg-r-400'));

const imageUrl = computed(() => props.variant.image || '');

const handleToggle = () => {
  emit('toggle', props.variant.item_code);
};
</script>

<template>
  <div
    class="flex items-center gap-3 py-2 px-3 rounded-lg transition-opacity duration-150"
    :class="isEnabled ? 'opacity-100' : 'opacity-50'"
  >
    <div
      v-if="imageUrl"
      class="w-8 h-8 rounded overflow-hidden shrink-0 bg-n-alpha-2"
    >
      <img
        :src="imageUrl"
        :alt="variant.item_name"
        class="w-full h-full object-cover"
        loading="lazy"
      />
    </div>
    <div
      v-else
      class="w-8 h-8 rounded shrink-0 bg-n-alpha-2 flex items-center justify-center"
    >
      <span class="i-lucide-package w-4 h-4 text-n-slate-9" />
    </div>

    <div class="flex flex-col min-w-0 flex-1">
      <span v-if="attributes" class="text-xs text-n-slate-11 truncate">
        {{ attributes }}
      </span>
      <span v-else class="text-xs text-n-slate-11 truncate">
        {{ variant.item_name }}
      </span>
    </div>

    <span v-if="displayPrice" class="text-xs text-n-slate-11 shrink-0">
      {{ displayPrice }}
      <span v-if="hasOverride" class="text-[10px] text-v-600 dark:text-v-400">
        {{ t('CAPTAIN_PRODUCTS.VARIANTS.CUSTOM_PRICE') }}
      </span>
    </span>

    <span class="flex items-center gap-1 text-xs text-n-slate-10 shrink-0">
      <span class="w-1.5 h-1.5 rounded-full" :class="stockDotColor" />
      {{ stockLabel }}
    </span>

    <button
      type="button"
      role="switch"
      :aria-checked="isEnabled"
      :aria-label="
        isEnabled
          ? t('CAPTAIN_PRODUCTS.VARIANTS.DISABLE_VARIANT', {
              name: variant.item_name,
            })
          : t('CAPTAIN_PRODUCTS.VARIANTS.ENABLE_VARIANT', {
              name: variant.item_name,
            })
      "
      class="relative inline-flex h-5 w-9 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-woot-500"
      :class="isEnabled ? 'bg-woot-500' : 'bg-n-slate-6'"
      @click="handleToggle"
    >
      <span
        class="pointer-events-none inline-block h-4 w-4 rounded-full bg-white shadow transform transition-transform duration-200"
        :class="isEnabled ? 'translate-x-4' : 'translate-x-0'"
      />
    </button>
  </div>
</template>
