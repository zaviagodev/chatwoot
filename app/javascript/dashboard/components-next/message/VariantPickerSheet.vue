<script setup>
import { ref, computed, onMounted, inject } from 'vue';
import CaptainErpProxy from 'dashboard/api/captain/erpProxy';
import Icon from 'next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  product: {
    type: Object,
    required: true,
  },
  assistantId: {
    type: Number,
    required: true,
  },
  hasCustomization: {
    type: Boolean,
    default: false,
  },
  // Pre-populate selections for back navigation / edit mode
  // Shape: { Size: "M", Color: "Blue" }
  initialSelections: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['add', 'close']);

const cache = inject('variantCache', null);

// State
const variants = ref([]);
const loading = ref(true);
const error = ref('');
const selectedOptions = ref({});

// Computed: extract unique attribute dimensions from variants
const attributeDimensions = computed(() => {
  const dims = {};
  variants.value.forEach(variant => {
    (variant.selectedOptions || []).forEach(opt => {
      if (!dims[opt.name]) {
        dims[opt.name] = new Set();
      }
      dims[opt.name].add(opt.value);
    });
  });
  // Convert sets to arrays preserving insertion order
  return Object.entries(dims).map(([name, values]) => ({
    name,
    values: [...values],
  }));
});

// Computed: all attributes selected?
const allSelected = computed(() => {
  return (
    attributeDimensions.value.length > 0 &&
    attributeDimensions.value.every(dim => selectedOptions.value[dim.name])
  );
});

// Computed: resolved variant (match ALL selected options)
const resolvedVariant = computed(() => {
  if (!allSelected.value) return null;
  return variants.value.find(v => {
    return (v.selectedOptions || []).every(
      opt => selectedOptions.value[opt.name] === opt.value
    );
  });
});

// Format currency helper
const formatCurrency = (amount, currency = 'THB') => {
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 2,
    }).format(amount);
  } catch {
    return `${currency} ${amount}`;
  }
};

// Computed: price range text
const priceRangeText = computed(() => {
  if (!variants.value.length) return '';
  const prices = variants.value
    .map(v => v.price?.amount)
    .filter(p => p != null);
  if (!prices.length) return '';
  const min = Math.min(...prices);
  const max = Math.max(...prices);
  const currency = variants.value[0]?.currency || 'THB';
  const fmt = amount => formatCurrency(amount, currency);
  return min === max ? fmt(min) : `${fmt(min)} – ${fmt(max)}`;
});

// Computed: can add to order?
const canAdd = computed(() => {
  return resolvedVariant.value && resolvedVariant.value.in_stock;
});

// Computed: button label
const buttonLabel = computed(() => {
  if (!allSelected.value) return 'Select all options';
  if (!resolvedVariant.value) return 'Combination unavailable';
  if (!resolvedVariant.value.in_stock) return 'Out of stock';
  return props.hasCustomization ? 'Continue →' : 'Add to Order';
});

const fetchVariants = async () => {
  const itemCode = props.product.item_code;

  // Check session cache first
  if (cache?.has(itemCode)) {
    variants.value = cache.get(itemCode);
    loading.value = false;
    return;
  }

  loading.value = true;
  error.value = '';
  try {
    const { data } = await CaptainErpProxy.getVariants({
      assistantId: props.assistantId,
      itemCode,
    });
    // Response chain: axios .data → Rails renders JSON → Frappe message extracted
    const result = data?.data || data || {};
    variants.value = result.variants || [];
    // Populate session cache
    cache?.set(itemCode, variants.value);
  } catch {
    error.value = 'Could not load variants. Please try again.';
    variants.value = [];
  } finally {
    loading.value = false;
  }
};

// Fetch variants on mount, then restore initial selections if provided
onMounted(async () => {
  await fetchVariants();
  if (props.initialSelections) {
    selectedOptions.value = { ...props.initialSelections };
  }
});

// Select an attribute pill
const selectOption = (dimensionName, value) => {
  selectedOptions.value = {
    ...selectedOptions.value,
    [dimensionName]: value,
  };
};

// Check if a pill is selected
const isSelected = (dimensionName, value) => {
  return selectedOptions.value[dimensionName] === value;
};

// Handle add to order
const handleAdd = () => {
  if (!canAdd.value || !resolvedVariant.value) return;
  emit('add', {
    item_code: resolvedVariant.value.id,
    item_name: resolvedVariant.value.title,
    price: resolvedVariant.value.price?.amount || 0,
    currency: resolvedVariant.value.currency || 'THB',
    image: resolvedVariant.value.image || props.product.image_url || null,
    selected_options: resolvedVariant.value.selectedOptions || [],
    stock_status: 'in_stock',
  });
};

// Retry on error
const handleRetry = () => {
  fetchVariants();
};
</script>

<template>
  <div class="variant-picker-sheet">
    <!-- Header -->
    <div class="variant-picker-header">
      <!-- eslint-disable vue/no-bare-strings-in-template -->
      <button
        class="variant-picker-close"
        aria-label="Close"
        @click="emit('close')"
      >
        <Icon icon="dismiss" :size="16" />
      </button>
      <!-- eslint-enable vue/no-bare-strings-in-template -->
    </div>

    <!-- Product info -->
    <div class="variant-picker-product">
      <img
        v-if="product.image_url || product.image"
        :src="product.image_url || product.image"
        :alt="product.item_name"
        class="variant-picker-product-img"
      />
      <div class="variant-picker-product-info">
        <span class="variant-picker-product-name">{{ product.item_name }}</span>
        <span class="variant-picker-product-price">{{ priceRangeText }}</span>
      </div>
    </div>

    <!-- Loading state -->
    <div v-if="loading" class="variant-picker-loading">
      <Spinner size="small" />
      <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
      <span>Loading variants...</span>
    </div>

    <!-- Error state -->
    <div v-else-if="error" class="variant-picker-error">
      <p>{{ error }}</p>
      <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
      <Button size="small" @click="handleRetry">Retry</Button>
    </div>

    <!-- Attribute pills -->
    <div v-else class="variant-picker-attributes">
      <div
        v-for="dim in attributeDimensions"
        :key="dim.name"
        class="variant-picker-dimension"
      >
        <label class="variant-picker-dimension-label">{{ dim.name }}</label>
        <div class="variant-picker-pills">
          <button
            v-for="value in dim.values"
            :key="value"
            class="variant-picker-pill"
            :class="{
              'variant-picker-pill--selected': isSelected(dim.name, value),
            }"
            @click="selectOption(dim.name, value)"
          >
            {{ value }}
          </button>
        </div>
      </div>

      <!-- Resolved variant info -->
      <div v-if="allSelected" class="variant-picker-resolved">
        <div v-if="resolvedVariant" class="variant-picker-resolved-info">
          <span class="variant-picker-resolved-price">
            {{
              resolvedVariant.price
                ? formatCurrency(
                    resolvedVariant.price.amount,
                    resolvedVariant.currency
                  )
                : ''
            }}
          </span>
          <span
            class="variant-picker-resolved-stock"
            :class="
              resolvedVariant.in_stock
                ? 'variant-picker-resolved-stock--in'
                : 'variant-picker-resolved-stock--out'
            "
          >
            <span class="variant-picker-stock-dot" />
            <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
            {{ resolvedVariant.in_stock ? 'In stock' : 'Out of stock' }}
          </span>
        </div>
        <!-- eslint-disable vue/no-bare-strings-in-template -->
        <div v-else class="variant-picker-resolved-unavailable">
          This combination is not available.
        </div>
        <!-- eslint-enable vue/no-bare-strings-in-template -->
      </div>
    </div>

    <!-- Action button -->
    <div v-if="!loading && !error" class="variant-picker-action">
      <Button
        class="variant-picker-add-btn"
        :disabled="!canAdd"
        @click="handleAdd"
      >
        {{ buttonLabel }}
      </Button>
    </div>
  </div>
</template>

<style scoped>
.variant-picker-sheet {
  display: flex;
  flex-direction: column;
  background: var(--white);
  border-top: 1px solid var(--s-75);
  border-radius: var(--border-radius-large) var(--border-radius-large) 0 0;
  padding: 12px 16px 16px;
  max-height: 400px;
  overflow-y: auto;
}

.variant-picker-header {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 8px;
}

.variant-picker-close {
  background: none;
  border: none;
  cursor: pointer;
  padding: 4px;
  border-radius: var(--border-radius-small);
  color: var(--s-600);
  display: flex;
  align-items: center;
}
.variant-picker-close:hover {
  background: var(--s-50);
}

.variant-picker-product {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 14px;
  padding-bottom: 12px;
  border-bottom: 1px solid var(--s-75);
}

.variant-picker-product-img {
  width: 44px;
  height: 44px;
  border-radius: var(--border-radius-small);
  object-fit: cover;
  flex-shrink: 0;
}

.variant-picker-product-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.variant-picker-product-name {
  font-size: var(--font-size-small);
  font-weight: 500;
  color: var(--s-900);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.variant-picker-product-price {
  font-size: var(--font-size-mini);
  color: var(--s-600);
}

.variant-picker-loading {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 20px 0;
  justify-content: center;
  color: var(--s-500);
  font-size: var(--font-size-small);
}

.variant-picker-error {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 16px 0;
  color: var(--r-500);
  font-size: var(--font-size-small);
}
.variant-picker-error p {
  margin: 0;
}

.variant-picker-attributes {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.variant-picker-dimension {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.variant-picker-dimension-label {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--s-500);
  font-weight: 500;
}

.variant-picker-pills {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.variant-picker-pill {
  border: 1px solid var(--s-200);
  border-radius: 8px;
  padding: 6px 14px;
  font-size: 13px;
  background: var(--white);
  color: var(--s-800);
  cursor: pointer;
  transition: all 0.15s ease;
  line-height: 1.2;
}
.variant-picker-pill:hover {
  border-color: var(--s-400);
}
.variant-picker-pill--selected {
  background: var(--w-500);
  color: var(--white);
  border-color: var(--w-500);
}

.variant-picker-resolved {
  padding-top: 12px;
  border-top: 1px solid var(--s-75);
}

.variant-picker-resolved-info {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.variant-picker-resolved-price {
  font-size: 16px;
  font-weight: 600;
  color: var(--s-900);
}

.variant-picker-resolved-stock {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: var(--font-size-mini);
}

.variant-picker-stock-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
}

.variant-picker-resolved-stock--in {
  color: var(--g-500);
}
.variant-picker-resolved-stock--in .variant-picker-stock-dot {
  background: var(--g-500);
}

.variant-picker-resolved-stock--out {
  color: var(--r-500);
}
.variant-picker-resolved-stock--out .variant-picker-stock-dot {
  background: var(--r-500);
}

.variant-picker-resolved-unavailable {
  font-size: var(--font-size-small);
  color: var(--s-500);
  text-align: center;
  padding: 4px 0;
}

.variant-picker-action {
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid var(--s-75);
}

.variant-picker-add-btn {
  width: 100%;
}
</style>
