<script setup>
import { ref, computed, watch, onMounted, inject } from 'vue';
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
  // Edit mode: pre-fill per-child variant selections { "SCRUB-TOP": "SCRUB-TOP-M-BLU" }
  initialBundleSelections: { type: Object, default: null },
  // Edit mode: pre-fill personalization values { "shared:Name": "สมชาย" }
  initialPersonalizationValues: { type: Object, default: null },
  isEditing: { type: Boolean, default: false },
});

const emit = defineEmits(['add', 'close']);

const cache = inject('bundleCache', null);

// State
const loading = ref(true);
const error = ref('');
const bundleData = ref(null);
const step = ref(1); // 1 = variant selection, 2 = personalization

const submitted = ref(false);

// Per-child variant selections: { "SCRUB-TOP": { Size: "M", Color: "Blue" } }
const childSelections = ref({});

// Personalization state
const fieldValues = ref({});

// Children that need variant selection (has_variants + allow_variant_selection)
const variantChildren = computed(() => {
  if (!bundleData.value) return [];
  return (bundleData.value.children || []).filter(
    c =>
      c.has_variants &&
      bundleData.value.allow_variant_selection &&
      !c.default_variant
  );
});

// Children with pre-locked variants (default_variant set)
const lockedChildren = computed(() => {
  if (!bundleData.value) return [];
  return (bundleData.value.children || []).filter(c => c.default_variant);
});

// Whether bundle has personalization fields
const hasPersonalization = computed(() => {
  const cust = bundleData.value?.customization;
  if (!cust) return false;
  if (cust.is_bundle && cust.bundle_items?.length) {
    return cust.bundle_items.some(bi => bi.fields?.length > 0);
  }
  return (cust.fields || []).length > 0;
});

// --- Personalization logic ---

// Gather all fields grouped by child + shared
const personalizationGroups = computed(() => {
  const cust = bundleData.value?.customization;
  if (!cust) return [];

  if (cust.is_bundle && cust.bundle_items?.length) {
    const groups = [];
    // Shared fields first
    const sharedFields = [];
    cust.bundle_items.forEach(bi => {
      (bi.fields || []).forEach(f => {
        if (f.shared) {
          sharedFields.push({ ...f, fieldPrefix: 'shared' });
        }
      });
    });
    if (sharedFields.length) {
      // Deduplicate shared fields by label
      const seen = new Set();
      const deduped = [];
      sharedFields.forEach(f => {
        if (!seen.has(f.label)) {
          seen.add(f.label);
          deduped.push(f);
        }
      });
      groups.push({ title: 'Shared', fields: deduped, childCode: null });
    }
    // Per-child fields
    cust.bundle_items.forEach(bi => {
      const childFields = (bi.fields || [])
        .filter(f => !f.shared)
        .map(f => ({ ...f, fieldPrefix: bi.item_code }));
      if (childFields.length) {
        groups.push({
          title: bi.item_name || bi.item_code,
          fields: childFields,
          childCode: bi.item_code,
        });
      }
    });
    return groups;
  }

  // Non-bundle customization (shouldn't happen for bundles, but handle gracefully)
  if ((cust.fields || []).length) {
    return [
      {
        title: null,
        fields: (cust.fields || []).map(f => ({ ...f, fieldPrefix: 'shared' })),
        childCode: null,
      },
    ];
  }
  return [];
});

// Rules per child/shared group
const getRulesForGroup = group => {
  const cust = bundleData.value?.customization;
  if (!cust) return [];
  if (cust.is_bundle && cust.bundle_items?.length) {
    if (group.childCode) {
      const bi = cust.bundle_items.find(b => b.item_code === group.childCode);
      return bi?.rules || [];
    }
    // Shared rules: collect from all children
    const allRules = [];
    cust.bundle_items.forEach(bi => {
      allRules.push(...(bi.rules || []));
    });
    return allRules;
  }
  return cust.rules || [];
};

// Rule evaluation per group — returns { visible, required, forced } per group
const getGroupRuleResult = group => {
  const rules = getRulesForGroup(group);
  if (!rules.length) return { visible: {}, required: {}, forced: {} };

  // Get values for this group's fields (using prefixed keys)
  const vals = {};
  group.fields.forEach(f => {
    const key = `${f.fieldPrefix}:${f.label}`;
    vals[f.label] = fieldValues.value[key] || '';
  });
  return evaluateRules(group.fields, rules, vals);
};

// Visible fields per group
const getVisibleFields = group => {
  const result = getGroupRuleResult(group);
  return group.fields.filter(f => result.visible[f.label] !== false);
};

// Init personalization values
const initPersonalizationValues = () => {
  const vals = {};
  personalizationGroups.value.forEach(group => {
    group.fields.forEach(f => {
      const key = `${f.fieldPrefix}:${f.label}`;
      vals[key] = '';
    });
  });
  // Overlay initial values for edit mode
  if (props.initialPersonalizationValues) {
    Object.entries(props.initialPersonalizationValues).forEach(([k, v]) => {
      if (k in vals) vals[k] = v;
    });
  }
  fieldValues.value = vals;
};

// Initialize selections from loaded bundle data (used by both fetch + cache paths)
const initSelectionsFromData = () => {
  const selections = {};
  variantChildren.value.forEach(child => {
    selections[child.item_code] = {};
  });
  if (props.initialBundleSelections) {
    variantChildren.value.forEach(child => {
      const selectedVariantCode =
        props.initialBundleSelections[child.item_code];
      if (selectedVariantCode && child.variants?.variants) {
        const variant = child.variants.variants.find(
          v => v.id === selectedVariantCode
        );
        if (variant) {
          const map = {};
          (variant.selectedOptions || []).forEach(opt => {
            map[opt.name] = opt.value;
          });
          selections[child.item_code] = map;
        }
      }
    });
  }
  childSelections.value = selections;
  initPersonalizationValues();
  if (variantChildren.value.length === 0) {
    step.value = hasPersonalization.value ? 2 : 1;
  }
};

const fetchBundleInfo = async () => {
  const itemCode = props.product.item_code;

  // Check session cache first
  if (cache?.has(itemCode)) {
    bundleData.value = cache.get(itemCode);
    initSelectionsFromData();
    loading.value = false;
    return;
  }

  loading.value = true;
  error.value = '';
  try {
    const { data } = await CaptainErpProxy.getBundleInfo({
      assistantId: props.assistantId,
      itemCode,
    });
    const result = data?.data || data || {};
    if (result.error) {
      error.value = result.error;
      return;
    }
    bundleData.value = result;
    // Populate session cache
    cache?.set(itemCode, result);
    initSelectionsFromData();
  } catch {
    error.value = 'Could not load bundle info. Please try again.';
  } finally {
    loading.value = false;
  }
};

// Fetch bundle info on mount
onMounted(async () => {
  await fetchBundleInfo();
});

// Extract attribute dimensions per child (same logic as VariantPickerSheet)
const getChildDimensions = childCode => {
  const child = (bundleData.value?.children || []).find(
    c => c.item_code === childCode
  );
  if (!child?.variants?.variants) return [];
  const dims = {};
  child.variants.variants.forEach(variant => {
    (variant.selectedOptions || []).forEach(opt => {
      if (!dims[opt.name]) dims[opt.name] = new Set();
      dims[opt.name].add(opt.value);
    });
  });
  return Object.entries(dims).map(([name, values]) => ({
    name,
    values: [...values],
  }));
};

// Resolve variant for a child based on current selections
const getResolvedVariant = childCode => {
  const child = (bundleData.value?.children || []).find(
    c => c.item_code === childCode
  );
  const sels = childSelections.value[childCode] || {};
  const dims = getChildDimensions(childCode);
  if (!dims.length) return null;
  const allSelected = dims.every(d => sels[d.name]);
  if (!allSelected) return null;
  return (child?.variants?.variants || []).find(v =>
    (v.selectedOptions || []).every(opt => sels[opt.name] === opt.value)
  );
};

// Check all variant children have valid selections
const allVariantsSelected = computed(() => {
  return variantChildren.value.every(child => {
    const resolved = getResolvedVariant(child.item_code);
    return resolved && resolved.in_stock;
  });
});

// Check if a child has all its variant dimensions selected
const isChildComplete = childCode => {
  const dims = getChildDimensions(childCode);
  if (!dims.length) return true;
  const sels = childSelections.value[childCode] || {};
  return dims.every(d => sels[d.name]);
};

// Select a pill for a child
const selectChildOption = (childCode, dimName, value) => {
  childSelections.value = {
    ...childSelections.value,
    [childCode]: {
      ...(childSelections.value[childCode] || {}),
      [dimName]: value,
    },
  };
  if (submitted.value) submitted.value = false;
};

const isChildSelected = (childCode, dimName, value) => {
  return (childSelections.value[childCode] || {})[dimName] === value;
};

// Step 1 button
const step1ButtonLabel = computed(() => {
  if (!allVariantsSelected.value) return 'Select all variants';
  return hasPersonalization.value ? 'Continue →' : 'Add to Order';
});

// Apply forced values from rules
watch(
  () =>
    personalizationGroups.value.map(g => ({
      group: g,
      result: getGroupRuleResult(g),
    })),
  groupResults => {
    groupResults.forEach(({ group, result }) => {
      Object.entries(result.forced || {}).forEach(([label, val]) => {
        if (val !== null) {
          const key = `${group.fields.find(f => f.label === label)?.fieldPrefix || 'shared'}:${label}`;
          if (fieldValues.value[key] !== val) {
            fieldValues.value[key] = val;
          }
        }
      });
    });
  },
  { deep: true }
);

// Addon total
const addonTotal = computed(() => {
  let total = 0;
  personalizationGroups.value.forEach(group => {
    const visible = getVisibleFields(group);
    visible.forEach(f => {
      if (f.addon_price) {
        const key = `${f.fieldPrefix}:${f.label}`;
        const val = fieldValues.value[key] || '';
        if (f.field_type === 'Toggle' && val === '1') {
          total += f.addon_price;
        } else if (f.field_type !== 'Toggle' && val) {
          total += f.addon_price;
        }
      }
    });
  });
  return total;
});

// Validation: all required visible fields filled
const isPersonalizationValid = computed(() => {
  return personalizationGroups.value.every(group => {
    const ruleResult = getGroupRuleResult(group);
    const visible = getVisibleFields(group);
    return visible.every(f => {
      const isReq =
        ruleResult.required[f.label] !== undefined
          ? ruleResult.required[f.label]
          : !!f.required;
      const key = `${f.fieldPrefix}:${f.label}`;
      return !(isReq && !fieldValues.value[key]);
    });
  });
});

// Format currency
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

// Update a personalization field value (key is prefixed)
const updateField = (prefixedKey, value) => {
  fieldValues.value = { ...fieldValues.value, [prefixedKey]: value };
  if (submitted.value) submitted.value = false;
};

// Field component resolver
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

// Per-field error messages for personalization (shown after submit attempt)
const personalizationFieldErrors = computed(() => {
  const errors = {};
  if (!submitted.value) return errors;
  personalizationGroups.value.forEach(group => {
    const ruleResult = getGroupRuleResult(group);
    const visible = getVisibleFields(group);
    visible.forEach(f => {
      const isReq =
        ruleResult.required[f.label] !== undefined
          ? ruleResult.required[f.label]
          : !!f.required;
      const key = `${f.fieldPrefix}:${f.label}`;
      if (isReq && !fieldValues.value[key]) {
        errors[key] = 'Required';
      }
    });
  });
  return errors;
});

// Build and emit add event
const emitAdd = () => {
  // Build bundle_variant_selections: { "SCRUB-TOP": "SCRUB-TOP-M-BLU" }
  const bundleVariantSelections = {};
  variantChildren.value.forEach(child => {
    const resolved = getResolvedVariant(child.item_code);
    if (resolved) {
      bundleVariantSelections[child.item_code] = resolved.id;
    }
  });
  // Add locked variants
  lockedChildren.value.forEach(child => {
    bundleVariantSelections[child.item_code] = child.default_variant;
  });

  // Build customizations dict (prefixed keys)
  const customizations = {};
  if (hasPersonalization.value) {
    personalizationGroups.value.forEach(group => {
      const visible = getVisibleFields(group);
      visible.forEach(f => {
        const key = `${f.fieldPrefix}:${f.label}`;
        const val = fieldValues.value[key];
        if (val !== undefined && val !== null) {
          customizations[key] = val;
        }
      });
    });
  }

  // Build children summary for display
  const summaryParts = [];
  variantChildren.value.forEach(child => {
    const resolved = getResolvedVariant(child.item_code);
    if (resolved) {
      const childName =
        child.item_name.split(' ').slice(-1)[0] || child.item_name;
      const optValues = (resolved.selectedOptions || [])
        .map(o => o.value)
        .join(' / ');
      summaryParts.push(`${childName}: ${optValues}`);
    }
  });

  // Build personalization summary
  let custSummary = '';
  if (Object.keys(customizations).length) {
    const parts = [];
    Object.entries(customizations).some(([key, val]) => {
      if (val) {
        const label = key.includes(':')
          ? key.split(':').slice(1).join(':')
          : key;
        const display = val === '1' ? 'Yes' : val;
        parts.push(`${label}: ${display}`);
      }
      return parts.length >= 2;
    });
    custSummary = parts.join(', ');
  }

  emit('add', {
    item_code: props.product.item_code,
    item_name: bundleData.value?.item_name || props.product.item_name,
    price: props.product.price ?? 0,
    currency: props.product.currency || 'THB',
    image: bundleData.value?.image || props.product.image_url || null,
    selected_options: [],
    stock_status: 'in_stock',
    is_bundle: true,
    bundle_variant_selections:
      Object.keys(bundleVariantSelections).length > 0
        ? bundleVariantSelections
        : null,
    bundle_children_summary: summaryParts.join(', '),
    customizations:
      Object.keys(customizations).length > 0 ? customizations : null,
    addon_total: addonTotal.value,
    customization_summary: custSummary,
  });
};

// Handle step 1 → step 2 or direct add
const handleStep1Continue = () => {
  submitted.value = true;
  if (!allVariantsSelected.value) return;
  if (hasPersonalization.value) {
    submitted.value = false;
    step.value = 2;
  } else {
    emitAdd();
  }
};

// Handle step 2 add
const handleStep2Add = () => {
  submitted.value = true;
  if (!isPersonalizationValid.value) return;
  emitAdd();
};

const handleRetry = () => fetchBundleInfo();
</script>

<template>
  <div class="bundle-config-sheet">
    <!-- Header -->
    <div class="bundle-header">
      <!-- eslint-disable vue/no-bare-strings-in-template -->
      <button
        v-if="step === 2 && variantChildren.length > 0"
        class="bundle-back"
        aria-label="Back"
        @click="step = 1"
      >
        <Icon icon="i-lucide-arrow-left" :size="16" />
      </button>
      <!-- eslint-enable vue/no-bare-strings-in-template -->
      <div class="bundle-header-spacer" />
      <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
      <button class="bundle-close" aria-label="Close" @click="emit('close')">
        <Icon icon="i-lucide-x" :size="16" />
      </button>
    </div>

    <!-- Product info -->
    <div class="bundle-product">
      <img
        v-if="product.image_url || product.image"
        :src="product.image_url || product.image"
        :alt="product.item_name"
        class="bundle-product-img"
      />
      <div class="bundle-product-info">
        <span class="bundle-product-name">{{ product.item_name }}</span>
        <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
        <span class="bundle-product-badge">Bundle</span>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="bundle-loading">
      <Spinner size="small" />
      <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
      <span>Loading bundle...</span>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="bundle-error">
      <p>{{ error }}</p>
      <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
      <Button size="small" @click="handleRetry">Retry</Button>
    </div>

    <!-- Step 1: Per-child variant selection -->
    <template v-else-if="step === 1 && variantChildren.length > 0">
      <div class="bundle-variants">
        <div
          v-for="child in variantChildren"
          :key="child.item_code"
          class="bundle-child-section"
        >
          <!-- Child header -->
          <div class="bundle-child-header">
            <img
              v-if="child.image"
              :src="child.image"
              :alt="child.item_name"
              class="bundle-child-img"
            />
            <span class="bundle-child-name">{{ child.item_name }}</span>
          </div>

          <!-- Attribute pills -->
          <div
            v-for="dim in getChildDimensions(child.item_code)"
            :key="dim.name"
            class="bundle-dimension"
          >
            <label class="bundle-dimension-label">{{ dim.name }}</label>
            <div class="bundle-pills">
              <button
                v-for="value in dim.values"
                :key="value"
                class="!border !border-solid !rounded-lg !px-3 !py-1.5 text-xs leading-tight cursor-pointer transition-all duration-150"
                :class="
                  isChildSelected(child.item_code, dim.name, value)
                    ? '!border-n-blue-9 !bg-n-blue-9 text-white'
                    : '!border-n-weak bg-n-solid-1 text-n-slate-12 hover:!border-n-slate-9'
                "
                @click="selectChildOption(child.item_code, dim.name, value)"
              >
                {{ value }}
              </button>
            </div>
          </div>

          <!-- Validation error for incomplete selection -->
          <!-- eslint-disable vue/no-bare-strings-in-template -->
          <span
            v-if="submitted && !isChildComplete(child.item_code)"
            class="bundle-child-error"
          >
            Select all options
          </span>
          <!-- eslint-enable vue/no-bare-strings-in-template -->

          <!-- Resolved variant info -->
          <div
            v-if="getResolvedVariant(child.item_code)"
            class="bundle-resolved"
          >
            <span class="bundle-resolved-price">
              {{
                getResolvedVariant(child.item_code).price
                  ? formatCurrency(
                      getResolvedVariant(child.item_code).price.amount,
                      getResolvedVariant(child.item_code).currency
                    )
                  : ''
              }}
            </span>
            <span
              class="bundle-resolved-stock"
              :class="
                getResolvedVariant(child.item_code).in_stock
                  ? 'bundle-resolved-stock--in'
                  : 'bundle-resolved-stock--out'
              "
            >
              <span class="bundle-stock-dot" />
              <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
              {{
                getResolvedVariant(child.item_code).in_stock
                  ? 'In stock'
                  : 'Out of stock'
              }}
            </span>
          </div>
        </div>

        <!-- Locked children info -->
        <div
          v-for="child in lockedChildren"
          :key="'locked-' + child.item_code"
          class="bundle-child-section bundle-child-locked"
        >
          <div class="bundle-child-header">
            <span class="bundle-child-name"
              >{{ child.item_name }}:
              <span class="bundle-locked-variant">{{
                child.default_variant
              }}</span></span
            >
          </div>
        </div>
      </div>

      <!-- Step 1 action -->
      <div class="bundle-action">
        <Button
          class="bundle-add-btn"
          :disabled="!allVariantsSelected"
          @click="handleStep1Continue"
        >
          {{ step1ButtonLabel }}
        </Button>
      </div>
    </template>

    <!-- Step 2: Personalization -->
    <template
      v-else-if="
        step === 2 ||
        (step === 1 && variantChildren.length === 0 && hasPersonalization)
      "
    >
      <div class="bundle-personalization">
        <div
          v-for="group in personalizationGroups"
          :key="group.title || 'default'"
          class="bundle-pers-group"
        >
          <h4 v-if="group.title" class="bundle-pers-group-title">
            {{ group.title }}
          </h4>

          <template
            v-for="field in getVisibleFields(group)"
            :key="`${field.fieldPrefix}:${field.label}`"
          >
            <component
              :is="fieldComponent(field.field_type)"
              :field="field"
              :model-value="
                fieldValues[`${field.fieldPrefix}:${field.label}`] || ''
              "
              :assistant-id="assistantId"
              :is-required="
                getGroupRuleResult(group).required[field.label] ??
                !!field.required
              "
              :error="
                personalizationFieldErrors[
                  `${field.fieldPrefix}:${field.label}`
                ] || ''
              "
              @update:model-value="
                updateField(`${field.fieldPrefix}:${field.label}`, $event)
              "
            />
          </template>
        </div>

        <!-- Addon total -->
        <div v-if="addonTotal > 0" class="bundle-addon-total">
          <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
          <span>Personalization</span>
          <span>+{{ formatCurrency(addonTotal) }}</span>
        </div>
      </div>

      <!-- Step 2 action -->
      <div class="bundle-action">
        <Button
          class="bundle-add-btn"
          :disabled="!isPersonalizationValid"
          @click="handleStep2Add"
        >
          <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
          {{ isEditing ? 'Update' : 'Add to Order' }}
        </Button>
      </div>
    </template>

    <!-- No config needed (all pre-locked, no personalization) -->
    <template v-else-if="!loading && !error">
      <div class="bundle-no-config">
        <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
        <p>This bundle has no configurable options.</p>
      </div>
      <div class="bundle-action">
        <Button class="bundle-add-btn" @click="emitAdd">
          <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
          {{ isEditing ? 'Update' : 'Add to Order' }}
        </Button>
      </div>
    </template>
  </div>
</template>

<style scoped>
.bundle-config-sheet {
  display: flex;
  flex-direction: column;
  background: var(--white);
  border-top: 1px solid var(--s-75);
  border-radius: var(--border-radius-large) var(--border-radius-large) 0 0;
  padding: 12px 16px 16px;
  max-height: 450px;
  overflow-y: auto;
}

.bundle-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}
.bundle-header-spacer {
  flex: 1;
}
.bundle-back,
.bundle-close {
  background: none;
  border: none;
  cursor: pointer;
  padding: 4px;
  border-radius: var(--border-radius-small);
  color: var(--s-600);
  display: flex;
  align-items: center;
}
.bundle-back:hover,
.bundle-close:hover {
  background: var(--s-50);
}

.bundle-product {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 14px;
  padding-bottom: 12px;
  border-bottom: 1px solid var(--s-75);
}
.bundle-product-img {
  width: 44px;
  height: 44px;
  border-radius: var(--border-radius-small);
  object-fit: cover;
  flex-shrink: 0;
}
.bundle-product-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.bundle-product-name {
  font-size: var(--font-size-small);
  font-weight: 500;
  color: var(--s-900);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.bundle-product-badge {
  display: inline-block;
  font-size: 10px;
  color: var(--s-500);
  background: var(--s-50);
  padding: 1px 6px;
  border-radius: 4px;
  width: fit-content;
}

.bundle-loading {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 20px 0;
  justify-content: center;
  color: var(--s-500);
  font-size: var(--font-size-small);
}

.bundle-error {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 16px 0;
  color: var(--r-500);
  font-size: var(--font-size-small);
}
.bundle-error p {
  margin: 0;
}

.bundle-variants {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.bundle-child-section {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding-bottom: 12px;
  border-bottom: 1px solid var(--s-50);
}
.bundle-child-section:last-child {
  border-bottom: none;
}

.bundle-child-header {
  display: flex;
  align-items: center;
  gap: 8px;
}
.bundle-child-img {
  width: 28px;
  height: 28px;
  border-radius: 4px;
  object-fit: cover;
  flex-shrink: 0;
}
.bundle-child-name {
  font-size: 13px;
  font-weight: 500;
  color: var(--s-800);
}
.bundle-child-error {
  font-size: 11px;
  color: var(--r-500);
}
.bundle-child-locked {
  opacity: 0.7;
}
.bundle-locked-variant {
  font-weight: 400;
  color: var(--s-500);
}

.bundle-dimension {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.bundle-dimension-label {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--s-500);
  font-weight: 500;
}
.bundle-pills {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
/* bundle-pill styles moved to inline Tailwind classes (see template) —
   _base.scss global button{border-0 border-none} overrides scoped CSS */

.bundle-resolved {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 4px;
}
.bundle-resolved-price {
  font-size: 14px;
  font-weight: 600;
  color: var(--s-900);
}
.bundle-resolved-stock {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: var(--font-size-mini);
}
.bundle-stock-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
}
.bundle-resolved-stock--in {
  color: var(--g-500);
}
.bundle-resolved-stock--in .bundle-stock-dot {
  background: var(--g-500);
}
.bundle-resolved-stock--out {
  color: var(--r-500);
}
.bundle-resolved-stock--out .bundle-stock-dot {
  background: var(--r-500);
}

.bundle-personalization {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.bundle-pers-group {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.bundle-pers-group-title {
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--s-600);
  margin: 0;
  padding-bottom: 4px;
  border-bottom: 1px solid var(--s-50);
}
.bundle-addon-total {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 12px;
  border-top: 1px solid var(--s-75);
  font-size: 13px;
  font-weight: 500;
  color: var(--s-700);
}

.bundle-action {
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid var(--s-75);
}
.bundle-add-btn {
  width: 100%;
}

.bundle-no-config {
  padding: 16px 0;
  text-align: center;
  color: var(--s-500);
  font-size: var(--font-size-small);
}
.bundle-no-config p {
  margin: 0;
}
</style>
