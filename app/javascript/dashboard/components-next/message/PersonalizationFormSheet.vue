<script setup>
import { ref, computed, watch, onMounted, nextTick, inject } from 'vue';
import CaptainErpProxy from 'dashboard/api/captain/erpProxy';
import Icon from 'next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import PersonalizationTextField from './PersonalizationTextField.vue';
import PersonalizationSelectField from './PersonalizationSelectField.vue';
import PersonalizationToggleField from './PersonalizationToggleField.vue';
import PersonalizationFileField from './PersonalizationFileField.vue';
import { evaluateRules } from 'dashboard/helper/personalizationRules';

const props = defineProps({
  product: { type: Object, required: true },
  assistantId: { type: Number, required: true },
  // Optional: variant data passed from combined flow
  variantData: { type: Object, default: null },
  // Optional: pre-fill values for edit mode
  initialValues: { type: Object, default: null },
  // Whether we're editing an existing item
  isEditing: { type: Boolean, default: false },
});

const emit = defineEmits(['add', 'close', 'back']);

const cache = inject('customizationCache', null);

// State
const fields = ref([]);
const rules = ref([]);
const loading = ref(true);
const error = ref('');
const fieldValues = ref({});
const submitted = ref(false);
const fieldRefs = ref([]);

// Initialize field values from loaded fields + optional initialValues overlay
const initFieldValues = () => {
  const vals = {};
  fields.value.forEach(f => {
    vals[f.label] = '';
  });
  if (props.initialValues) {
    Object.entries(props.initialValues).forEach(([label, val]) => {
      if (label in vals) {
        vals[label] = val;
      }
    });
  }
  fieldValues.value = vals;
};

const fetchCustomization = async () => {
  // Always use the template/parent item_code for customization lookup,
  // NOT the variant SKU — the template is defined on the parent item
  const itemCode = props.product.item_code;

  // Check session cache first
  if (cache?.has(itemCode)) {
    const cached = cache.get(itemCode);
    fields.value = cached.fields;
    rules.value = cached.rules;
    initFieldValues();
    loading.value = false;
    return;
  }

  loading.value = true;
  error.value = '';
  try {
    const { data } = await CaptainErpProxy.getCustomization({
      assistantId: props.assistantId,
      itemCode,
    });
    const result = data?.data || data || {};
    fields.value = (result.fields || []).sort(
      (a, b) => (a.sort_order || 0) - (b.sort_order || 0)
    );
    rules.value = result.rules || [];
    // Populate session cache
    cache?.set(itemCode, { fields: fields.value, rules: rules.value });
    initFieldValues();
  } catch {
    error.value = 'Could not load personalization options. Please try again.';
  } finally {
    loading.value = false;
  }
};

// Fetch customization template on mount
onMounted(async () => {
  await fetchCustomization();
});

// Rule engine: evaluate on every value change
const ruleResult = computed(() => {
  if (!fields.value.length) {
    return { visible: {}, forced: {}, required: {} };
  }
  return evaluateRules(fields.value, rules.value, fieldValues.value);
});

// Apply forced values from rules
watch(
  () => ruleResult.value.forced,
  forced => {
    Object.entries(forced).forEach(([label, val]) => {
      if (val !== null && fieldValues.value[label] !== val) {
        fieldValues.value[label] = val;
      }
    });
  },
  { deep: true }
);

// Visible fields (filtered by rule engine)
const visibleFields = computed(() => {
  return fields.value.filter(f => ruleResult.value.visible[f.label] !== false);
});

// Addon total: sum of addon_price for active fields
const addonTotal = computed(() => {
  let total = 0;
  visibleFields.value.forEach(f => {
    if (f.addon_price) {
      const val = fieldValues.value[f.label] || '';
      // Addon active if: toggle is "1", or text/select has a value
      if (f.field_type === 'Toggle' && val === '1') {
        total += f.addon_price;
      } else if (f.field_type !== 'Toggle' && val) {
        total += f.addon_price;
      }
    }
  });
  return total;
});

// Validation: all visible required fields must be filled
const isValid = computed(() => {
  return visibleFields.value.every(f => {
    const isReq =
      ruleResult.value.required[f.label] !== undefined
        ? ruleResult.value.required[f.label]
        : !!f.required;
    return !(isReq && !fieldValues.value[f.label]);
  });
});

// Per-field error messages (only shown after first submit attempt)
const fieldErrors = computed(() => {
  const errors = {};
  if (!submitted.value) return errors;
  visibleFields.value.forEach(f => {
    const isReq =
      ruleResult.value.required[f.label] !== undefined
        ? ruleResult.value.required[f.label]
        : !!f.required;
    const val = fieldValues.value[f.label] || '';
    if (isReq && !val) {
      errors[f.label] = 'Required';
    } else if (
      f.field_type === 'Text Input' &&
      f.max_characters &&
      val.length > f.max_characters
    ) {
      errors[f.label] = `Max ${f.max_characters} characters`;
    }
  });
  return errors;
});

// Button label
const buttonLabel = computed(() => {
  if (!isValid.value) return 'Fill required fields';
  return props.isEditing ? 'Update' : 'Add to Order';
});

// Product display info
const productName = computed(() => {
  if (props.variantData) {
    return `${props.product.item_name} — ${props.variantData.item_name}`;
  }
  return props.product.item_name;
});

const productPrice = computed(() => {
  const price = props.variantData?.price ?? props.product.price;
  const currency =
    props.variantData?.currency || props.product.currency || 'THB';
  if (!price && price !== 0) return '';
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 2,
    }).format(price);
  } catch {
    return `${currency} ${price}`;
  }
});

const formatAddonTotal = computed(() => {
  if (!addonTotal.value) return '';
  const currency =
    props.variantData?.currency || props.product.currency || 'THB';
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 2,
    }).format(addonTotal.value);
  } catch {
    return `${currency} ${addonTotal.value}`;
  }
});

// Build customization summary for order list display
const buildSummary = () => {
  const parts = [];
  visibleFields.value.some(f => {
    const val = fieldValues.value[f.label];
    if (val) {
      let display = val;
      if (f.field_type === 'Toggle') {
        display = val === '1' ? 'Yes' : 'No';
      } else if (f.field_type === 'File Upload') {
        display = 'Uploaded';
      }
      parts.push(`${f.label}: ${display}`);
    }
    return parts.length >= 3;
  });
  return parts.join(', ');
};

// Handle add to order
const handleAdd = () => {
  submitted.value = true;
  if (!isValid.value) {
    // Scroll to first error field
    nextTick(() => {
      const firstErrorEl = fieldRefs.value.find(
        el =>
          el &&
          el.querySelector(
            '.personalization-field-error, .personalization-toggle-error'
          )
      );
      if (firstErrorEl) {
        firstErrorEl.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
      }
    });
    return;
  }

  // Build customizations dict (only visible fields with values)
  const customizations = {};
  visibleFields.value.forEach(f => {
    const val = fieldValues.value[f.label];
    if (val !== undefined && val !== null) {
      customizations[f.label] = val;
    }
  });

  const itemCode = props.variantData?.item_code || props.product.item_code;
  const price = props.variantData?.price ?? props.product.price ?? 0;
  const currency =
    props.variantData?.currency || props.product.currency || 'THB';
  const image =
    props.variantData?.image ||
    props.product.image_url ||
    props.product.image ||
    null;

  emit('add', {
    item_code: itemCode,
    item_name: productName.value,
    price,
    currency,
    image,
    selected_options: props.variantData?.selected_options || [],
    stock_status:
      props.variantData?.stock_status ||
      props.product.stock_status ||
      'in_stock',
    customizations,
    addon_total: addonTotal.value,
    customization_summary: buildSummary(),
  });
};

const handleRetry = () => {
  fetchCustomization();
};

// Update a field value (clears submitted flag so errors refresh on next attempt)
const updateField = (label, value) => {
  fieldValues.value = { ...fieldValues.value, [label]: value };
  if (submitted.value) submitted.value = false;
};

// Determine field component
const fieldComponent = fieldType => {
  switch (fieldType) {
    case 'Text Input':
      return PersonalizationTextField;
    case 'Select':
      return PersonalizationSelectField;
    case 'Toggle':
      return PersonalizationToggleField;
    case 'File Upload':
      return PersonalizationFileField;
    default:
      return PersonalizationTextField;
  }
};
</script>

<template>
  <div class="personalization-sheet">
    <!-- Header -->
    <div class="personalization-header">
      <!-- eslint-disable vue/no-bare-strings-in-template -->
      <button
        v-if="variantData"
        class="personalization-back"
        aria-label="Back"
        @click="emit('back')"
      >
        <Icon icon="i-lucide-arrow-left" :size="16" />
      </button>
      <!-- eslint-enable vue/no-bare-strings-in-template -->
      <div class="personalization-header-spacer" />
      <!-- eslint-disable vue/no-bare-strings-in-template -->
      <button
        class="personalization-close"
        aria-label="Close"
        @click="emit('close')"
      >
        <Icon icon="i-lucide-x" :size="16" />
      </button>
      <!-- eslint-enable vue/no-bare-strings-in-template -->
    </div>

    <!-- Product info -->
    <div class="personalization-product">
      <img
        v-if="product.image_url || product.image"
        :src="product.image_url || product.image"
        :alt="product.item_name"
        class="personalization-product-img"
      />
      <div class="personalization-product-info">
        <span class="personalization-product-name">{{ productName }}</span>
        <span class="personalization-product-price">{{ productPrice }}</span>
      </div>
    </div>

    <!-- Loading state -->
    <div v-if="loading" class="personalization-loading">
      <Spinner size="small" />
      <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
      <span>Loading personalization...</span>
    </div>

    <!-- Error state -->
    <div v-else-if="error" class="personalization-error">
      <p>{{ error }}</p>
      <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
      <Button size="small" @click="handleRetry">Retry</Button>
    </div>

    <!-- Fields -->
    <div v-else class="personalization-fields">
      <template v-for="(field, idx) in visibleFields" :key="field.label">
        <div
          :ref="
            el => {
              fieldRefs[idx] = el;
            }
          "
        >
          <component
            :is="fieldComponent(field.field_type)"
            :field="field"
            :model-value="fieldValues[field.label] || ''"
            :assistant-id="assistantId"
            :is-required="ruleResult.required[field.label] ?? !!field.required"
            :error="fieldErrors[field.label] || ''"
            @update:model-value="updateField(field.label, $event)"
          />
        </div>
      </template>

      <!-- Addon total -->
      <div v-if="addonTotal > 0" class="personalization-addon-total">
        <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
        <span>Personalization</span>
        <span>+{{ formatAddonTotal }}</span>
      </div>
    </div>

    <!-- Action button -->
    <div v-if="!loading && !error" class="personalization-action">
      <Button
        class="personalization-add-btn"
        :disabled="!isValid"
        @click="handleAdd"
      >
        {{ buttonLabel }}
      </Button>
    </div>
  </div>
</template>

<style scoped>
.personalization-sheet {
  display: flex;
  flex-direction: column;
  background: var(--white);
  border-top: 1px solid var(--s-75);
  border-radius: var(--border-radius-large) var(--border-radius-large) 0 0;
  padding: 12px 16px 16px;
  max-height: 450px;
  overflow-y: auto;
}

.personalization-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}
.personalization-header-spacer {
  flex: 1;
}
.personalization-back,
.personalization-close {
  background: none;
  border: none;
  cursor: pointer;
  padding: 4px;
  border-radius: var(--border-radius-small);
  color: var(--s-600);
  display: flex;
  align-items: center;
}
.personalization-back:hover,
.personalization-close:hover {
  background: var(--s-50);
}

.personalization-product {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 14px;
  padding-bottom: 12px;
  border-bottom: 1px solid var(--s-75);
}
.personalization-product-img {
  width: 44px;
  height: 44px;
  border-radius: var(--border-radius-small);
  object-fit: cover;
  flex-shrink: 0;
}
.personalization-product-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.personalization-product-name {
  font-size: var(--font-size-small);
  font-weight: 500;
  color: var(--s-900);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.personalization-product-price {
  font-size: var(--font-size-mini);
  color: var(--s-600);
}

.personalization-loading {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 20px 0;
  justify-content: center;
  color: var(--s-500);
  font-size: var(--font-size-small);
}

.personalization-error {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 16px 0;
  color: var(--r-500);
  font-size: var(--font-size-small);
}
.personalization-error p {
  margin: 0;
}

.personalization-fields {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.personalization-addon-total {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 12px;
  border-top: 1px solid var(--s-75);
  font-size: 13px;
  font-weight: 500;
  color: var(--s-700);
}

.personalization-action {
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid var(--s-75);
}
.personalization-add-btn {
  width: 100%;
}
</style>
