<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { useRoute, useRouter, onBeforeRouteLeave } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import CaptainProductsAPI from 'dashboard/api/captain/products';
import CaptainErpProxy from 'dashboard/api/captain/erpProxy';

import ProductDetailHeader from 'dashboard/components-next/captain/pageComponents/product/ProductDetailHeader.vue';
import ProductVariantsTable from 'dashboard/components-next/captain/pageComponents/product/ProductVariantsTable.vue';
import ProductSidebarCards from 'dashboard/components-next/captain/pageComponents/product/ProductSidebarCards.vue';
import OptionGroupsModal from 'dashboard/components-next/captain/pageComponents/product/OptionGroupsModal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();

const selectedAssistantId = computed(() => Number(route.params.assistantId));
const isNewProduct = computed(() => route.name === 'captain_product_new');
const productId = computed(() =>
  isNewProduct.value ? null : Number(route.params.productId)
);

// --- Data + Form state ---
const product = ref(null);
const isLoading = ref(true);
const loadError = ref(null);

const itemName = ref('');
const itemCode = ref('');
const itemGroup = ref('');
const status = ref('active');
const imageUrl = ref('');
const currency = ref('THB');
const price = ref('');
const stockQty = ref('');
const description = ref('');
const variants = ref([]);
const specs = ref([]);

const optionGroups = ref([]);
const showOptionsModal = ref(false);

const isSaving = ref(false);
const isResyncing = ref(false);
const errors = ref({});

const initForm = p => {
  itemName.value = p.item_name || '';
  itemCode.value = p.item_code || '';
  itemGroup.value = p.item_group || '';
  status.value = p.status || 'active';
  imageUrl.value = p.image_url || '';
  currency.value = p.currency || 'THB';
  price.value = p.price != null ? String(p.price) : '';
  stockQty.value = p.stock_qty != null ? String(p.stock_qty) : '';
  description.value = p.description || '';
  variants.value = JSON.parse(JSON.stringify(p.variants || []));
  specs.value = JSON.parse(JSON.stringify(p.specs || []));
  optionGroups.value = JSON.parse(JSON.stringify(p.option_groups || []));
  errors.value = {};
};

const fetchProduct = async () => {
  isLoading.value = true;
  loadError.value = null;
  try {
    const { data } = await CaptainProductsAPI.show({
      assistantId: selectedAssistantId.value,
      id: productId.value,
    });
    product.value = data;
    initForm(data);
  } catch (err) {
    loadError.value = err.response?.status === 404 ? 'not_found' : 'network';
  } finally {
    isLoading.value = false;
  }
};

const isErpSynced = computed(() => !!product.value?.erp_company);
const canResync = computed(
  () => isErpSynced.value && !!product.value?.item_code
);

const isDirty = computed(() => {
  if (isNewProduct.value) return itemName.value.trim() !== '';
  if (!product.value) return false;
  const p = product.value;
  return (
    itemName.value !== (p.item_name || '') ||
    itemCode.value !== (p.item_code || '') ||
    itemGroup.value !== (p.item_group || '') ||
    status.value !== (p.status || 'active') ||
    imageUrl.value !== (p.image_url || '') ||
    currency.value !== (p.currency || 'THB') ||
    price.value !== String(p.price ?? '') ||
    stockQty.value !== (p.stock_qty != null ? String(p.stock_qty) : '') ||
    description.value !== (p.description || '') ||
    JSON.stringify(variants.value) !== JSON.stringify(p.variants || []) ||
    JSON.stringify(specs.value) !== JSON.stringify(p.specs || []) ||
    JSON.stringify(optionGroups.value) !== JSON.stringify(p.option_groups || [])
  );
});

const canSave = computed(
  () => itemName.value.trim() && price.value && Number(price.value) > 0
);

const validate = () => {
  const e = {};
  if (!itemName.value.trim()) {
    e.itemName = t('CAPTAIN_PRODUCTS.FORM.ERRORS.NAME_REQUIRED');
  }
  if (!price.value || Number(price.value) <= 0) {
    e.price = t('CAPTAIN_PRODUCTS.FORM.ERRORS.PRICE_REQUIRED');
  }
  errors.value = e;
  return Object.keys(e).length === 0;
};

// Category autocomplete from store
const products = useMapGetter('captainProducts/getRecords');
const existingCategories = computed(() => {
  const cats = (products.value || []).map(p => p.item_group).filter(Boolean);
  return [...new Set(cats)];
});

const statusOptions = computed(() => [
  { value: 'active', label: t('CAPTAIN_PRODUCTS.FORM.STATUS_ACTIVE') },
  { value: 'draft', label: t('CAPTAIN_PRODUCTS.FORM.STATUS_DRAFT') },
  { value: 'archived', label: t('CAPTAIN_PRODUCTS.FORM.STATUS_ARCHIVED') },
]);

// --- Description source tracking ---
const getDescriptionSource = descChanged => {
  if (descChanged) return 'manual';
  return product.value?.description_source || 'manual';
};

// --- Save ---
const buildPayload = () => ({
  assistantId: selectedAssistantId.value,
  item_name: itemName.value,
  item_code: itemCode.value || undefined,
  item_group: itemGroup.value || undefined,
  status: status.value,
  price: Number(price.value),
  currency: currency.value,
  stock_qty: stockQty.value !== '' ? Number(stockQty.value) : null,
  description: description.value || undefined,
  image: imageUrl.value || undefined,
  variants: variants.value,
  specs: specs.value,
  option_groups: optionGroups.value,
});

const handleSave = async () => {
  if (!validate()) return;
  isSaving.value = true;

  if (isNewProduct.value) {
    try {
      const result = await store.dispatch(
        'captainProducts/create',
        buildPayload()
      );
      // Set product so isDirty=false and route guard won't block navigation
      product.value = result;
      initForm(result);
      useAlert(t('CAPTAIN_PRODUCTS.DETAIL.SAVED'));
      router.replace({
        name: 'captain_product_detail',
        params: { ...route.params, productId: result.id },
      });
    } catch {
      useAlert(t('CAPTAIN_PRODUCTS.DETAIL.SAVE_ERROR'));
    }
    isSaving.value = false;
    return;
  }

  const descChanged = description.value !== (product.value?.description || '');
  const payload = {
    ...buildPayload(),
    id: productId.value,
    description_source: getDescriptionSource(descChanged),
  };
  try {
    const result = await store.dispatch('captainProducts/update', payload);
    product.value = result;
    initForm(result);
    useAlert(t('CAPTAIN_PRODUCTS.DETAIL.SAVED'));
  } catch {
    useAlert(t('CAPTAIN_PRODUCTS.DETAIL.SAVE_ERROR'));
  }
  isSaving.value = false;
};

// --- Navigation ---
const navigateBack = () => {
  router.push({
    name: 'captain_assistants_products_index',
    params: {
      accountId: route.params.accountId,
      assistantId: route.params.assistantId,
    },
  });
};

// --- Delete ---
const deleteDialogRef = ref(null);
const handleDelete = () => deleteDialogRef.value?.open();
const handleDeleteConfirm = async () => {
  try {
    await store.dispatch('captainProducts/delete', {
      id: productId.value,
      assistantId: selectedAssistantId.value,
    });
    useAlert(t('CAPTAIN_PRODUCTS.DETAIL.DELETED'));
    navigateBack();
  } catch {
    useAlert(t('CAPTAIN_PRODUCTS.DETAIL.DELETE_ERROR'));
  }
};

// --- Re-sync from Workspace ---
const resyncConflictDialogRef = ref(null);
const pendingResyncData = ref(null);

const applyResyncData = (data, keepLocalDescription = false) => {
  const detail = data.detail;
  itemName.value = detail.item_name || itemName.value;
  itemCode.value = detail.item_code || itemCode.value;
  itemGroup.value = detail.item_group || itemGroup.value;
  imageUrl.value = detail.image || imageUrl.value;
  currency.value = detail.currency || currency.value;
  price.value = detail.price != null ? String(detail.price) : price.value;
  stockQty.value =
    detail.stock_qty != null ? String(detail.stock_qty) : stockQty.value;
  if (!keepLocalDescription) {
    description.value =
      detail.long_description || detail.description || description.value;
  }
  if (detail.variants?.length) {
    variants.value = JSON.parse(JSON.stringify(detail.variants));
  }
  if (detail.specs?.length) {
    specs.value = JSON.parse(JSON.stringify(detail.specs));
  }
};

const handleResync = async () => {
  if (!canResync.value) return;
  isResyncing.value = true;
  try {
    const { data } = await CaptainErpProxy.getProductDetail({
      assistantId: selectedAssistantId.value,
      itemCode: product.value.item_code,
    });
    const detail = data.data || data;
    const resyncPayload = { detail, formattedText: data.formatted_text };
    const source = product.value.description_source;
    if (source === 'manual' || source === 'ai') {
      pendingResyncData.value = resyncPayload;
      resyncConflictDialogRef.value?.open();
    } else {
      applyResyncData(resyncPayload, false);
      useAlert(t('CAPTAIN_PRODUCTS.FORM.RESYNC_SUCCESS'));
    }
  } catch {
    useAlert(t('CAPTAIN_PRODUCTS.FORM.RESYNC_ERROR'));
  }
  isResyncing.value = false;
};

const handleResyncReplace = () => {
  if (!pendingResyncData.value) return;
  applyResyncData(pendingResyncData.value, false);
  pendingResyncData.value = null;
  useAlert(t('CAPTAIN_PRODUCTS.FORM.RESYNC_SUCCESS'));
};

const handleResyncKeepLocal = () => {
  if (!pendingResyncData.value) return;
  applyResyncData(pendingResyncData.value, true);
  pendingResyncData.value = null;
  useAlert(t('CAPTAIN_PRODUCTS.FORM.RESYNC_SUCCESS'));
};

// --- Variant helpers ---
const addVariant = () => {
  variants.value.push({
    item_name: '',
    item_code: '',
    price: '',
    stock_qty: null,
    enabled: true,
    image: '',
    description_override: '',
    price_override: false,
    attributes: [],
  });
};
const removeVariant = index => variants.value.splice(index, 1);
const updateVariant = ({ index, field, value }) => {
  variants.value[index][field] = value;
};

// --- Option groups: cartesian product + smart merge ---
const cartesianProduct = groups => {
  if (groups.length === 0) return [];
  return groups.reduce(
    (acc, group) =>
      acc.flatMap(combo =>
        group.values.map(val => [
          ...combo,
          { attribute: group.name, value: val },
        ])
      ),
    [[]]
  );
};

const variantMatchKey = attrs => {
  if (!attrs?.length) return '';
  return JSON.stringify(
    [...attrs].sort((a, b) => a.attribute.localeCompare(b.attribute))
  );
};

const applyOptionGroups = newGroups => {
  optionGroups.value = newGroups;
  if (newGroups.length === 0) return;

  // Build lookup of existing variants by attribute key
  const existingMap = new Map();
  variants.value.forEach(v => {
    const key = variantMatchKey(v.attributes);
    if (key) existingMap.set(key, v);
  });

  // Generate cartesian product
  const combos = cartesianProduct(newGroups);
  const parentSku = itemCode.value || '';
  const parentPriceNum = price.value ? Number(price.value) : null;

  const generated = combos.map(attrs => {
    const key = variantMatchKey(attrs);
    const existing = existingMap.get(key);

    if (existing) {
      // Preserve existing variant, update attributes to canonical order
      return { ...existing, attributes: attrs };
    }

    // New variant — auto-generate name and SKU
    const nameParts = attrs.map(a => a.value);
    const skuParts = attrs.map(a => a.value.toUpperCase().replace(/\s+/g, ''));
    const autoSku = parentSku
      ? `${parentSku}-${skuParts.join('-')}`
      : skuParts.join('-');

    return {
      item_name: nameParts.join(' / '),
      item_code: autoSku,
      price: parentPriceNum ?? '',
      stock_qty: null,
      enabled: true,
      image: '',
      description_override: '',
      price_override: false,
      attributes: attrs,
    };
  });

  // Keep manually-added variants (those without attribute-key match in generated set)
  const generatedKeys = new Set(
    generated.map(v => variantMatchKey(v.attributes))
  );
  const manualVariants = variants.value.filter(v => {
    const key = variantMatchKey(v.attributes);
    return !key || !generatedKeys.has(key);
  });

  // Only keep manual variants that weren't matched by the old option groups
  const oldGroupNames = new Set(
    (product.value?.option_groups || []).map(g => g.name)
  );
  const keptManual = manualVariants.filter(v => {
    // Keep variants with no attributes, or attributes from non-option-group sources
    if (!v.attributes?.length) return true;
    return !v.attributes.every(a => oldGroupNames.has(a.attribute));
  });

  variants.value = [...generated, ...keptManual];
};

// --- Spec helpers ---
const addSpec = () => specs.value.push({ label: '', value: '' });
const removeSpec = index => specs.value.splice(index, 1);
const updateSpec = ({ index, field, value }) => {
  specs.value[index][field] = value;
};

// --- Unsaved changes guard ---
const discardDialogRef = ref(null);
const pendingNavigation = ref(null);

onBeforeRouteLeave((_to, _from, next) => {
  if (isDirty.value) {
    pendingNavigation.value = next;
    discardDialogRef.value?.open();
    return;
  }
  next();
});

const handleDiscard = () => {
  if (pendingNavigation.value) {
    pendingNavigation.value();
    pendingNavigation.value = null;
  }
};

const handleDiscardCancel = () => {
  pendingNavigation.value = null;
};

// --- Keyboard shortcut ---
const handleKeydown = e => {
  if ((e.metaKey || e.ctrlKey) && e.key === 's') {
    e.preventDefault();
    if (isDirty.value && canSave.value && !isSaving.value) handleSave();
  }
};

onMounted(() => {
  if (isNewProduct.value) {
    product.value = {};
    isLoading.value = false;
  } else {
    fetchProduct();
  }
  window.addEventListener('keydown', handleKeydown);
});
onUnmounted(() => window.removeEventListener('keydown', handleKeydown));

// --- Image preview debounce ---
const debouncedImageUrl = ref('');
let imageDebounceTimer = null;
watch(imageUrl, val => {
  clearTimeout(imageDebounceTimer);
  imageDebounceTimer = setTimeout(() => {
    debouncedImageUrl.value = val;
  }, 500);
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <ProductDetailHeader
      v-if="product"
      :product-name="
        isNewProduct
          ? t('CAPTAIN_PRODUCTS.DETAIL.NEW_PRODUCT_TITLE')
          : itemName || product.item_name
      "
      :status="status"
      :is-dirty="isDirty"
      :is-saving="isSaving"
      :is-erp-synced="isErpSynced"
      :is-resyncing="isResyncing"
      :can-save="canSave"
      :is-new="isNewProduct"
      @save="handleSave"
      @delete="handleDelete"
      @resync="handleResync"
      @back="navigateBack"
    />

    <main class="flex-1 overflow-y-auto px-6 py-6">
      <div class="w-full max-w-[72rem] mx-auto">
        <!-- Loading skeleton -->
        <div v-if="isLoading" class="flex flex-col lg:flex-row gap-6">
          <div class="flex-1 lg:w-3/5 space-y-6">
            <div class="h-10 rounded-lg bg-n-alpha-2 animate-pulse" />
            <div class="h-8 rounded-lg bg-n-alpha-2 animate-pulse w-2/3" />
            <div class="h-60 rounded-lg bg-n-alpha-2 animate-pulse" />
            <div class="h-32 rounded-lg bg-n-alpha-2 animate-pulse" />
          </div>
          <div class="lg:w-2/5 space-y-6">
            <div class="h-40 rounded-lg bg-n-alpha-2 animate-pulse" />
            <div class="h-32 rounded-lg bg-n-alpha-2 animate-pulse" />
            <div class="h-48 rounded-lg bg-n-alpha-2 animate-pulse" />
          </div>
        </div>

        <!-- Error: Not found -->
        <div
          v-else-if="loadError === 'not_found'"
          class="flex flex-col items-center justify-center py-20 gap-4"
        >
          <span class="i-lucide-package-x w-12 h-12 text-n-slate-8" />
          <p class="text-base text-n-slate-11">
            {{ t('CAPTAIN_PRODUCTS.DETAIL.NOT_FOUND') }}
          </p>
          <Button
            :label="t('CAPTAIN_PRODUCTS.DETAIL.NOT_FOUND_BACK')"
            icon="i-lucide-arrow-left"
            color="slate"
            variant="faded"
            @click="navigateBack"
          />
        </div>

        <!-- Error: Network -->
        <div
          v-else-if="loadError === 'network'"
          class="flex flex-col items-center justify-center py-20 gap-4"
        >
          <span class="i-lucide-wifi-off w-12 h-12 text-n-slate-8" />
          <p class="text-base text-n-slate-11">
            {{ t('CAPTAIN_PRODUCTS.DETAIL.LOAD_ERROR') }}
          </p>
          <Button
            :label="t('CAPTAIN_PRODUCTS.DETAIL.LOAD_RETRY')"
            icon="i-lucide-refresh-cw"
            color="slate"
            variant="faded"
            @click="fetchProduct"
          />
        </div>

        <!-- Two-column layout -->
        <div v-else-if="product" class="flex flex-col lg:flex-row gap-6">
          <!-- LEFT COLUMN (60%) -->
          <div class="flex-1 lg:w-3/5 space-y-6">
            <!-- Source indicator -->
            <div
              v-if="!isNewProduct"
              class="flex items-center gap-2 text-xs text-n-slate-10"
            >
              <span
                v-if="isErpSynced"
                class="i-lucide-refresh-cw w-3.5 h-3.5"
              />
              <span v-else class="i-lucide-pencil w-3.5 h-3.5" />
              {{
                isErpSynced
                  ? t('CAPTAIN_PRODUCTS.DETAIL.SOURCE_ERP')
                  : t('CAPTAIN_PRODUCTS.DETAIL.SOURCE_MANUAL')
              }}
            </div>

            <!-- Basics section -->
            <div class="space-y-3">
              <h3
                class="text-xs font-semibold uppercase tracking-wider text-n-slate-9"
              >
                {{ t('CAPTAIN_PRODUCTS.DETAIL.SECTION_BASICS') }}
              </h3>
              <div>
                <label class="text-sm text-n-slate-12 block mb-1">
                  {{ t('CAPTAIN_PRODUCTS.FORM.NAME_LABEL') }}
                  <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
                  <span class="text-r-500">*</span>
                </label>
                <Input
                  v-model="itemName"
                  :placeholder="t('CAPTAIN_PRODUCTS.FORM.NAME_PLACEHOLDER')"
                  :class="{ 'border-r-500': errors.itemName }"
                />
                <span
                  v-if="errors.itemName"
                  class="text-xs text-r-500 mt-0.5 block"
                >
                  {{ errors.itemName }}
                </span>
              </div>
              <div class="flex gap-3">
                <div class="flex-1">
                  <label class="text-sm text-n-slate-12 block mb-1">
                    {{ t('CAPTAIN_PRODUCTS.FORM.SKU_LABEL') }}
                  </label>
                  <Input
                    v-model="itemCode"
                    :placeholder="t('CAPTAIN_PRODUCTS.FORM.SKU_PLACEHOLDER')"
                    class="font-mono"
                  />
                </div>
                <div class="w-32">
                  <label class="text-sm text-n-slate-12 block mb-1">
                    {{ t('CAPTAIN_PRODUCTS.FORM.STATUS_LABEL') }}
                  </label>
                  <select v-model="status" class="!mb-0">
                    <option
                      v-for="opt in statusOptions"
                      :key="opt.value"
                      :value="opt.value"
                    >
                      {{ opt.label }}
                    </option>
                  </select>
                </div>
              </div>
              <div>
                <label class="text-sm text-n-slate-12 block mb-1">
                  {{ t('CAPTAIN_PRODUCTS.FORM.CATEGORY_LABEL') }}
                </label>
                <Input
                  v-model="itemGroup"
                  :placeholder="t('CAPTAIN_PRODUCTS.FORM.CATEGORY_PLACEHOLDER')"
                  list="detail-category-list"
                />
                <datalist id="detail-category-list">
                  <option
                    v-for="cat in existingCategories"
                    :key="cat"
                    :value="cat"
                  />
                </datalist>
              </div>
            </div>

            <!-- Media section -->
            <div class="space-y-3">
              <h3
                class="text-xs font-semibold uppercase tracking-wider text-n-slate-9"
              >
                {{ t('CAPTAIN_PRODUCTS.DETAIL.SECTION_MEDIA') }}
              </h3>
              <div
                v-if="debouncedImageUrl"
                class="w-60 h-60 rounded-lg overflow-hidden bg-n-alpha-2 mb-3"
              >
                <img
                  :src="debouncedImageUrl"
                  :alt="itemName"
                  class="w-full h-full object-cover"
                  @error="$event.target.classList.add('hidden')"
                />
              </div>
              <div
                v-else
                class="w-60 h-16 rounded-lg border-2 border-dashed border-n-slate-4 flex items-center justify-center mb-3"
              >
                <span class="text-xs text-n-slate-9">
                  {{ t('CAPTAIN_PRODUCTS.DETAIL.ADD_IMAGE_URL') }}
                </span>
              </div>
              <label class="text-sm text-n-slate-12 block mb-1">
                {{ t('CAPTAIN_PRODUCTS.FORM.IMAGE_LABEL') }}
              </label>
              <Input
                v-model="imageUrl"
                :placeholder="t('CAPTAIN_PRODUCTS.FORM.IMAGE_PLACEHOLDER')"
                type="url"
              />
            </div>

            <!-- Description section -->
            <div class="space-y-3">
              <div class="flex items-center gap-2">
                <h3
                  class="text-xs font-semibold uppercase tracking-wider text-n-slate-9"
                >
                  {{ t('CAPTAIN_PRODUCTS.DETAIL.SECTION_DESCRIPTION') }}
                </h3>
                <span
                  v-if="!isNewProduct && product.description_source === 'ai'"
                  class="text-xs px-1.5 py-0.5 rounded bg-v-50 text-v-700 dark:bg-v-900/20 dark:text-v-300"
                >
                  {{ t('CAPTAIN_PRODUCTS.DETAIL.DESCRIPTION_AI_TAG') }}
                </span>
              </div>
              <textarea
                v-model="description"
                :placeholder="
                  t('CAPTAIN_PRODUCTS.FORM.DESCRIPTION_PLACEHOLDER')
                "
                rows="6"
                class="!mb-0 !h-auto resize-none"
              />
              <p class="text-xs text-n-slate-9">
                {{ t('CAPTAIN_PRODUCTS.DETAIL.DESCRIPTION_HINT') }}
              </p>
            </div>

            <!-- Variants section -->
            <ProductVariantsTable
              :variants="variants"
              :parent-price="price"
              :option-groups="optionGroups"
              @add="addVariant"
              @remove="removeVariant"
              @update:variant="updateVariant"
              @manage-options="showOptionsModal = true"
            />

            <!-- Option groups modal -->
            <OptionGroupsModal
              v-model="showOptionsModal"
              :option-groups="optionGroups"
              :existing-variants="variants"
              :read-only="isErpSynced"
              @apply="applyOptionGroups"
            />
          </div>

          <!-- RIGHT COLUMN (40%) -->
          <div class="lg:w-2/5">
            <ProductSidebarCards
              :currency="currency"
              :price="price"
              :stock-qty="stockQty"
              :specs="specs"
              :formatted-text="product.formatted_text"
              :errors="errors"
              @update:currency="currency = $event"
              @update:price="price = $event"
              @update:stock-qty="stockQty = $event"
              @add-spec="addSpec"
              @remove-spec="removeSpec"
              @update:spec="updateSpec"
            />
          </div>
        </div>
      </div>
    </main>

    <!-- Discard confirmation dialog -->
    <Dialog
      ref="discardDialogRef"
      type="alert"
      :title="t('CAPTAIN_PRODUCTS.FORM.DISCARD_TITLE')"
      :description="t('CAPTAIN_PRODUCTS.FORM.DISCARD_MESSAGE')"
      :confirm-button-label="t('CAPTAIN_PRODUCTS.FORM.DISCARD_CONFIRM')"
      @confirm="handleDiscard"
      @cancel="handleDiscardCancel"
    />

    <!-- Delete confirmation dialog -->
    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="t('CAPTAIN_PRODUCTS.DETAIL.DELETE_TITLE')"
      :description="
        t('CAPTAIN_PRODUCTS.DETAIL.DELETE_MESSAGE', {
          name: product?.item_name,
        })
      "
      :confirm-button-label="t('CAPTAIN_PRODUCTS.DETAIL.DELETE_CONFIRM')"
      @confirm="handleDeleteConfirm"
    />

    <!-- Re-sync conflict dialog -->
    <Dialog
      ref="resyncConflictDialogRef"
      type="alert"
      :title="t('CAPTAIN_PRODUCTS.FORM.RESYNC_CONFLICT_TITLE')"
      :description="t('CAPTAIN_PRODUCTS.FORM.RESYNC_CONFLICT_MESSAGE')"
      :confirm-button-label="t('CAPTAIN_PRODUCTS.FORM.RESYNC_REPLACE')"
      :cancel-button-label="t('CAPTAIN_PRODUCTS.FORM.RESYNC_KEEP_LOCAL')"
      @confirm="handleResyncReplace"
      @cancel="handleResyncKeepLocal"
    />
  </section>
</template>
