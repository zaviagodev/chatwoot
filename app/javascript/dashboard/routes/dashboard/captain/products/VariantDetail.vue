<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { useRoute, useRouter, onBeforeRouteLeave } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import CaptainProductsAPI from 'dashboard/api/captain/products';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();

const assistantId = computed(() => Number(route.params.assistantId));
const productId = computed(() => Number(route.params.productId));
const variantIndex = computed(() => {
  const idx = Number(route.params.variantIndex);
  if (Number.isNaN(idx) || idx < 0) return -1;
  return idx;
});

// --- Data + Form state ---
const product = ref(null);
const isLoading = ref(true);
const loadError = ref(null);
const variantName = ref('');
const variantSku = ref('');
const variantPrice = ref('');
const variantStockQty = ref('');
const variantEnabled = ref(true);
const variantImage = ref('');
const variantDescriptionOverride = ref('');
const variantPriceOverride = ref(false);
const isSaving = ref(false);

// --- Image preview debounce ---
const debouncedVariantImage = ref('');
let imageDebounceTimer = null;
watch(variantImage, val => {
  clearTimeout(imageDebounceTimer);
  imageDebounceTimer = setTimeout(() => {
    debouncedVariantImage.value = val;
  }, 500);
});

const initForm = v => {
  variantName.value = v.item_name || '';
  variantSku.value = v.item_code || '';
  variantPrice.value = v.price != null ? String(v.price) : '';
  variantStockQty.value = v.stock_qty != null ? String(v.stock_qty) : '';
  variantEnabled.value = v.enabled !== false;
  variantImage.value = v.image || '';
  variantDescriptionOverride.value = v.description_override || '';
  variantPriceOverride.value = !!v.price_override;
  debouncedVariantImage.value = v.image || '';
};

const fetchProduct = async () => {
  isLoading.value = true;
  loadError.value = null;

  if (variantIndex.value < 0) {
    loadError.value = 'variant_not_found';
    isLoading.value = false;
    return;
  }

  try {
    const { data } = await CaptainProductsAPI.show({
      assistantId: assistantId.value,
      id: productId.value,
    });
    product.value = data;
    const variants = data.variants || [];
    if (variantIndex.value >= variants.length) {
      loadError.value = 'variant_not_found';
    } else {
      initForm(variants[variantIndex.value]);
    }
  } catch (err) {
    loadError.value = err.response?.status === 404 ? 'not_found' : 'network';
  } finally {
    isLoading.value = false;
  }
};

const currentVariant = computed(() => {
  if (!product.value) return null;
  const variants = product.value.variants || [];
  if (variantIndex.value < 0 || variantIndex.value >= variants.length) {
    return null;
  }
  return variants[variantIndex.value];
});

const isDirty = computed(() => {
  if (!currentVariant.value) return false;
  const v = currentVariant.value;
  return (
    variantName.value !== (v.item_name || '') ||
    variantSku.value !== (v.item_code || '') ||
    variantPrice.value !== (v.price != null ? String(v.price) : '') ||
    variantStockQty.value !==
      (v.stock_qty != null ? String(v.stock_qty) : '') ||
    variantEnabled.value !== (v.enabled !== false) ||
    variantImage.value !== (v.image || '') ||
    variantDescriptionOverride.value !== (v.description_override || '') ||
    variantPriceOverride.value !== !!v.price_override
  );
});

const canSave = computed(() => variantName.value.trim().length > 0);

const parentPriceDisplay = computed(() => {
  if (!product.value) return '';
  const p = product.value;
  return `${p.currency || 'THB'} ${p.price ?? 0}`;
});

// --- Build full product save payload (mirrors Show.vue) ---
const buildProductPayload = updatedVariants => {
  const p = product.value;
  return {
    assistantId: assistantId.value,
    id: productId.value,
    item_name: p.item_name,
    item_code: p.item_code || undefined,
    item_group: p.item_group || undefined,
    status: p.status || 'active',
    price: p.price != null ? Number(p.price) : 0,
    currency: p.currency || 'THB',
    stock_qty: p.stock_qty != null ? Number(p.stock_qty) : null,
    description: p.description || undefined,
    image: p.image_url || undefined,
    variants: updatedVariants,
    specs: p.specs || [],
    description_source: p.description_source || 'manual',
  };
};

// --- Save (CRITICAL: spread existing variant to preserve all fields) ---
const handleSave = async () => {
  if (!canSave.value || isSaving.value) return;
  isSaving.value = true;
  try {
    const updatedVariants = JSON.parse(
      JSON.stringify(product.value.variants || [])
    );
    updatedVariants[variantIndex.value] = {
      ...updatedVariants[variantIndex.value],
      item_name: variantName.value,
      item_code: variantSku.value || undefined,
      price: variantPrice.value !== '' ? Number(variantPrice.value) : null,
      stock_qty:
        variantStockQty.value !== '' ? Number(variantStockQty.value) : null,
      enabled: variantEnabled.value,
      image: variantImage.value || undefined,
      description_override: variantDescriptionOverride.value || undefined,
      price_override: variantPriceOverride.value,
    };
    const payload = buildProductPayload(updatedVariants);
    const result = await store.dispatch('captainProducts/update', payload);
    product.value = result;
    initForm(result.variants[variantIndex.value]);
    useAlert(t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.SAVED'));
  } catch {
    useAlert(t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.SAVE_ERROR'));
  }
  isSaving.value = false;
};

// --- Navigation ---
const navigateToProduct = () => {
  router.push({
    name: 'captain_product_detail',
    params: {
      accountId: route.params.accountId,
      assistantId: route.params.assistantId,
      productId: route.params.productId,
    },
  });
};

// --- Delete ---
const deleteDialogRef = ref(null);
const handleDelete = () => deleteDialogRef.value?.open();
const handleDeleteConfirm = async () => {
  isSaving.value = true;
  try {
    const updatedVariants = JSON.parse(
      JSON.stringify(product.value.variants || [])
    );
    updatedVariants.splice(variantIndex.value, 1);
    const payload = buildProductPayload(updatedVariants);
    await store.dispatch('captainProducts/update', payload);
    useAlert(t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.DELETED'));
    navigateToProduct();
  } catch {
    useAlert(t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.DELETE_ERROR'));
  }
  isSaving.value = false;
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
  fetchProduct();
  window.addEventListener('keydown', handleKeydown);
});
onUnmounted(() => window.removeEventListener('keydown', handleKeydown));

const productName = computed(
  () => product.value?.item_name || t('CAPTAIN_PRODUCTS.DETAIL.NOT_FOUND')
);
const displayVariantName = computed(
  () =>
    variantName.value ||
    currentVariant.value?.item_name ||
    `Variant ${variantIndex.value + 1}`
);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <!-- Header -->
    <header
      v-if="product && !loadError"
      class="sticky top-0 z-10 bg-n-surface-1 border-b border-n-slate-3"
    >
      <div class="w-full max-w-[72rem] mx-auto px-6 py-4">
        <div
          class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
        >
          <!-- Breadcrumb: Product Name > Variants > Variant Name -->
          <div class="flex items-center gap-1.5 min-w-0 text-sm">
            <button
              class="flex items-center gap-1.5 text-n-slate-10 hover:text-n-slate-12 shrink-0"
              @click="navigateToProduct"
            >
              <span class="i-lucide-arrow-left w-4 h-4" />
              {{ productName }}
            </button>
            <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
            <span class="text-n-slate-8 shrink-0">/</span>
            <span class="text-n-slate-10 shrink-0">
              {{
                t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.BREADCRUMB_VARIANTS')
              }}
            </span>
            <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
            <span class="text-n-slate-8 shrink-0">/</span>
            <span class="text-n-slate-12 font-medium truncate">
              {{ displayVariantName }}
            </span>
            <span
              v-if="isDirty"
              class="w-1.5 h-1.5 rounded-full bg-b-500 shrink-0"
              :aria-label="t('CAPTAIN_PRODUCTS.DETAIL.UNSAVED_DOT_ARIA')"
            />
          </div>

          <!-- Actions -->
          <div class="flex items-center gap-2 shrink-0">
            <Button
              :label="
                t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.DELETE_VARIANT')
              "
              color="ruby"
              variant="faded"
              size="sm"
              @click="handleDelete"
            />
            <Button
              :label="t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.SAVE_CHANGES')"
              size="sm"
              :disabled="!isDirty || !canSave || isSaving"
              :is-loading="isSaving"
              @click="handleSave"
            />
          </div>
        </div>
      </div>
    </header>

    <main class="flex-1 overflow-y-auto px-6 py-6">
      <div class="w-full max-w-[72rem] mx-auto">
        <!-- Loading skeleton -->
        <div v-if="isLoading" class="flex flex-col lg:flex-row gap-6">
          <div class="flex-1 lg:w-3/5 space-y-6">
            <div class="h-10 rounded-lg bg-n-alpha-2 animate-pulse" />
            <div class="h-10 rounded-lg bg-n-alpha-2 animate-pulse w-2/3" />
            <div class="h-40 rounded-lg bg-n-alpha-2 animate-pulse" />
          </div>
          <div class="lg:w-2/5 space-y-6">
            <div class="h-24 rounded-lg bg-n-alpha-2 animate-pulse" />
            <div class="h-20 rounded-lg bg-n-alpha-2 animate-pulse" />
          </div>
        </div>

        <!-- Error: Product not found -->
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
            @click="navigateToProduct"
          />
        </div>

        <!-- Error: Variant not found (invalid index) -->
        <div
          v-else-if="loadError === 'variant_not_found'"
          class="flex flex-col items-center justify-center py-20 gap-4"
        >
          <span class="i-lucide-package-x w-12 h-12 text-n-slate-8" />
          <p class="text-base text-n-slate-11">
            {{ t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.NOT_FOUND') }}
          </p>
          <Button
            :label="t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.NOT_FOUND_BACK')"
            icon="i-lucide-arrow-left"
            color="slate"
            variant="faded"
            @click="navigateToProduct"
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

        <!-- Two-column variant form -->
        <div v-else-if="currentVariant" class="flex flex-col lg:flex-row gap-6">
          <!-- LEFT COLUMN (60%) -->
          <div class="flex-1 lg:w-3/5 space-y-6">
            <!-- Name -->
            <div>
              <label class="text-sm text-n-slate-12 block mb-1">
                {{ t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.NAME_LABEL') }}
                <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
                <span class="text-r-500">*</span>
              </label>
              <Input
                v-model="variantName"
                :placeholder="
                  t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.NAME_PLACEHOLDER')
                "
              />
            </div>

            <!-- SKU -->
            <div>
              <label class="text-sm text-n-slate-12 block mb-1">
                {{ t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.SKU_LABEL') }}
              </label>
              <Input
                v-model="variantSku"
                :placeholder="
                  t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.SKU_PLACEHOLDER')
                "
                class="font-mono"
              />
            </div>

            <!-- Attributes (read-only pills) -->
            <div v-if="currentVariant.attributes?.length">
              <label class="text-sm text-n-slate-12 block mb-1">
                {{
                  t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.ATTRIBUTES_LABEL')
                }}
              </label>
              <div class="flex flex-wrap gap-1.5">
                <span
                  v-for="attr in currentVariant.attributes"
                  :key="attr.attribute"
                  class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded bg-n-alpha-2 text-xs text-n-slate-11"
                >
                  <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
                  {{ attr.attribute }}: {{ attr.value }}
                </span>
              </div>
            </div>

            <!-- Image -->
            <div>
              <label class="text-sm text-n-slate-12 block mb-1">
                {{ t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.IMAGE_LABEL') }}
              </label>
              <div
                v-if="debouncedVariantImage"
                class="w-40 h-40 rounded-lg overflow-hidden bg-n-alpha-2 mb-3"
              >
                <img
                  :src="debouncedVariantImage"
                  :alt="variantName"
                  class="w-full h-full object-cover"
                  @error="$event.target.classList.add('hidden')"
                />
              </div>
              <div
                v-else
                class="w-40 h-10 rounded-lg border-2 border-dashed border-n-slate-4 flex items-center justify-center mb-3"
              >
                <span class="i-lucide-image w-4 h-4 text-n-slate-7" />
              </div>
              <Input
                v-model="variantImage"
                :placeholder="
                  t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.IMAGE_PLACEHOLDER')
                "
                type="url"
              />
            </div>

            <!-- Description override -->
            <div>
              <label class="text-sm text-n-slate-12 block mb-1">
                {{
                  t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.DESCRIPTION_LABEL')
                }}
              </label>
              <textarea
                v-model="variantDescriptionOverride"
                :placeholder="
                  t(
                    'CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.DESCRIPTION_PLACEHOLDER'
                  )
                "
                rows="4"
                class="!mb-0 !h-auto resize-none"
              />
              <p class="text-xs text-n-slate-9 mt-1">
                {{
                  t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.DESCRIPTION_HINT')
                }}
              </p>
            </div>
          </div>

          <!-- RIGHT COLUMN (40%) — Status & Pricing -->
          <div class="lg:w-2/5 space-y-6">
            <!-- Enabled toggle -->
            <div
              class="flex items-center justify-between rounded-lg border border-n-slate-3 p-4"
            >
              <div>
                <span class="text-sm text-n-slate-12 block">
                  {{
                    t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.ENABLED_LABEL')
                  }}
                </span>
                <p class="text-xs text-n-slate-9 mt-0.5">
                  {{ t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.ENABLED_HINT') }}
                </p>
              </div>
              <Switch
                v-model="variantEnabled"
                :aria-label="
                  t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.ENABLED_LABEL')
                "
              />
            </div>

            <!-- Price -->
            <div class="rounded-lg border border-n-slate-3 p-4 space-y-3">
              <div>
                <label class="text-sm text-n-slate-12 block mb-1">
                  {{ t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.PRICE_LABEL') }}
                </label>
                <Input
                  v-model="variantPrice"
                  type="number"
                  :placeholder="
                    t(
                      'CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.PRICE_PLACEHOLDER'
                    )
                  "
                  min="0"
                  step="0.01"
                />
                <p
                  v-if="variantPriceOverride"
                  class="text-xs text-n-slate-9 mt-1"
                >
                  {{
                    t(
                      'CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.CUSTOM_PRICE_HINT',
                      { price: parentPriceDisplay }
                    )
                  }}
                </p>
              </div>

              <!-- Stock -->
              <div>
                <label class="text-sm text-n-slate-12 block mb-1">
                  {{ t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.STOCK_LABEL') }}
                </label>
                <Input
                  v-model="variantStockQty"
                  type="number"
                  :placeholder="
                    t(
                      'CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.STOCK_PLACEHOLDER'
                    )
                  "
                  min="0"
                  step="1"
                />
              </div>
            </div>
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
      :title="t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.DELETE_TITLE')"
      :description="
        t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.DELETE_MESSAGE', {
          name: displayVariantName,
        })
      "
      :confirm-button-label="
        t('CAPTAIN_PRODUCTS.DETAIL.VARIANT_DETAIL.DELETE_CONFIRM')
      "
      @confirm="handleDeleteConfirm"
    />
  </section>
</template>
