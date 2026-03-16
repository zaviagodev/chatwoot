<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import CaptainErpProxy from 'dashboard/api/captain/erpProxy';

const props = defineProps({
  isOpen: { type: Boolean, default: false },
  product: { type: Object, default: null },
  assistantId: { type: Number, required: true },
  existingCategories: { type: Array, default: () => [] },
});

const emit = defineEmits(['close', 'saved']);
const store = useStore();
const { t } = useI18n();

const isEditing = computed(() => !!props.product);
const title = computed(() =>
  isEditing.value
    ? props.product?.item_name || t('CAPTAIN_PRODUCTS.FORM.EDIT_TITLE')
    : t('CAPTAIN_PRODUCTS.FORM.ADD_TITLE')
);

// Form state
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

const isSaving = ref(false);
const isResyncing = ref(false);
const errors = ref({});

// Collapsible sections
const showVariants = ref(false);
const showSpecs = ref(false);
const showCaptainPreview = ref(false);

// Discard + delete + resync conflict dialogs
const discardDialogRef = ref(null);
const deleteDialogRef = ref(null);
const resyncConflictDialogRef = ref(null);
const pendingResyncData = ref(null);

const isErpSynced = computed(() => !!props.product?.erp_company);
const canResync = computed(
  () => isErpSynced.value && !!props.product?.item_code
);

const isDirty = computed(() => {
  if (!isEditing.value) {
    return !!(
      itemName.value ||
      itemCode.value ||
      itemGroup.value ||
      price.value ||
      stockQty.value ||
      description.value ||
      imageUrl.value ||
      variants.value.length > 0 ||
      specs.value.length > 0
    );
  }
  const p = props.product;
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
    JSON.stringify(specs.value) !== JSON.stringify(p.specs || [])
  );
});

const canSave = computed(() => {
  return itemName.value.trim() && price.value && Number(price.value) > 0;
});

// Reset form when drawer opens
watch(
  () => [props.isOpen, props.product],
  () => {
    if (props.isOpen) {
      errors.value = {};
      if (props.product) {
        const p = props.product;
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
        showVariants.value = !!(p.variants && p.variants.length);
        showSpecs.value = !!(p.specs && p.specs.length);
      } else {
        itemName.value = '';
        itemCode.value = '';
        itemGroup.value = '';
        status.value = 'active';
        imageUrl.value = '';
        currency.value = 'THB';
        price.value = '';
        stockQty.value = '';
        description.value = '';
        variants.value = [];
        specs.value = [];
        showVariants.value = false;
        showSpecs.value = false;
      }
    }
  },
  { immediate: true }
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

const handleClose = () => {
  if (isDirty.value) {
    discardDialogRef.value?.open();
  } else {
    emit('close');
  }
};

const handleDiscard = () => {
  emit('close');
};

const getDescriptionSource = descChanged => {
  if (!isEditing.value) return 'manual';
  if (descChanged) return 'manual';
  return props.product?.description_source || 'manual';
};

const handleSave = async () => {
  if (!validate()) return;
  isSaving.value = true;

  const descChanged = description.value !== (props.product?.description || '');

  const payload = {
    assistantId: props.assistantId,
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
    description_source: getDescriptionSource(descChanged),
  };

  try {
    if (isEditing.value) {
      payload.id = props.product.id;
      await store.dispatch('captainProducts/update', payload);
      useAlert(t('CAPTAIN_PRODUCTS.FORM.TOAST_UPDATED'));
    } else {
      await store.dispatch('captainProducts/create', payload);
      useAlert(t('CAPTAIN_PRODUCTS.FORM.TOAST_CREATED'));
    }
    emit('saved');
  } catch {
    useAlert(
      isEditing.value
        ? t('CAPTAIN_PRODUCTS.FORM.TOAST_UPDATE_ERROR')
        : t('CAPTAIN_PRODUCTS.FORM.TOAST_CREATE_ERROR')
    );
  }
  isSaving.value = false;
};

const handleDelete = () => {
  deleteDialogRef.value?.open();
};

const handleDeleteConfirm = async () => {
  try {
    await store.dispatch('captainProducts/delete', {
      id: props.product.id,
      assistantId: props.assistantId,
    });
    useAlert(t('CAPTAIN_PRODUCTS.FORM.TOAST_DELETED'));
    emit('saved');
  } catch {
    useAlert(t('CAPTAIN_PRODUCTS.FORM.TOAST_DELETE_ERROR'));
  }
};

// --- Re-sync from Workspace ---
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
  if (detail.variants && detail.variants.length) {
    variants.value = detail.variants;
    showVariants.value = true;
  }
  if (detail.specs && detail.specs.length) {
    specs.value = detail.specs;
    showSpecs.value = true;
  }
};

const handleResync = async () => {
  if (!canResync.value) return;
  isResyncing.value = true;

  try {
    const { data } = await CaptainErpProxy.getProductDetail({
      assistantId: props.assistantId,
      itemCode: props.product.item_code,
    });
    const detail = data.data || data;
    const resyncPayload = { detail, formattedText: data.formatted_text };

    // Check for local edits conflict using persisted value
    const source = props.product.description_source;
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
  if (pendingResyncData.value) {
    applyResyncData(pendingResyncData.value, false);
    pendingResyncData.value = null;
    useAlert(t('CAPTAIN_PRODUCTS.FORM.RESYNC_SUCCESS'));
  }
};

const handleResyncKeepLocal = () => {
  if (pendingResyncData.value) {
    applyResyncData(pendingResyncData.value, true);
    pendingResyncData.value = null;
    useAlert(t('CAPTAIN_PRODUCTS.FORM.RESYNC_SUCCESS'));
  }
};

// --- Variant helpers ---
const addVariant = () => {
  variants.value.push({ item_name: '', item_code: '', price: '' });
};

const removeVariant = index => {
  variants.value.splice(index, 1);
};

// --- Spec helpers ---
const addSpec = () => {
  specs.value.push({ label: '', value: '' });
};

const removeSpec = index => {
  specs.value.splice(index, 1);
};

const handleKeydown = event => {
  if (event.key === 'Escape') {
    handleClose();
  }
};

const currencies = ['THB', 'USD', 'EUR', 'JPY', 'GBP', 'CNY', 'SGD'];
const statusOptions = computed(() => [
  { value: 'active', label: t('CAPTAIN_PRODUCTS.FORM.STATUS_ACTIVE') },
  { value: 'draft', label: t('CAPTAIN_PRODUCTS.FORM.STATUS_DRAFT') },
  { value: 'archived', label: t('CAPTAIN_PRODUCTS.FORM.STATUS_ARCHIVED') },
]);
</script>

<template>
  <Teleport to="body">
    <Transition name="slide">
      <div
        v-if="isOpen"
        class="fixed inset-0 z-50 flex justify-end"
        @keydown="handleKeydown"
      >
        <!-- Backdrop -->
        <div
          class="absolute inset-0 bg-n-alpha-black1 backdrop-blur-[4px]"
          @click="handleClose"
        />

        <!-- Drawer panel -->
        <div
          class="relative w-[480px] max-w-full bg-n-surface-1 shadow-xl flex flex-col overflow-hidden"
        >
          <!-- Header -->
          <div
            class="flex items-center justify-between px-6 py-4 border-b border-n-slate-3"
          >
            <h2 class="text-base font-semibold text-n-slate-12 truncate">
              {{ title }}
            </h2>
            <button
              class="p-1 rounded hover:bg-n-slate-3 text-n-slate-9"
              @click="handleClose"
            >
              <span class="i-lucide-x text-lg" />
            </button>
          </div>

          <!-- Body -->
          <div class="flex-1 overflow-y-auto px-6 py-5 space-y-6">
            <!-- Source indicator -->
            <div v-if="isEditing" class="space-y-2">
              <div class="flex items-center gap-2 text-xs text-n-slate-10">
                <span
                  v-if="isErpSynced"
                  class="i-lucide-refresh-cw w-3.5 h-3.5"
                />
                <span v-else class="i-lucide-pencil w-3.5 h-3.5" />
                {{
                  isErpSynced
                    ? t('CAPTAIN_PRODUCTS.FORM.SOURCE_ERP')
                    : t('CAPTAIN_PRODUCTS.FORM.SOURCE_MANUAL')
                }}
              </div>
              <p v-if="isErpSynced" class="text-xs text-n-slate-9">
                {{ t('CAPTAIN_PRODUCTS.FORM.SOURCE_ERP_INFO') }}
              </p>
              <!-- Re-sync button -->
              <Button
                v-if="canResync"
                icon="i-lucide-refresh-cw"
                :label="
                  isResyncing
                    ? t('CAPTAIN_PRODUCTS.FORM.RESYNCING')
                    : t('CAPTAIN_PRODUCTS.FORM.RESYNC')
                "
                color="slate"
                variant="faded"
                size="xs"
                :is-loading="isResyncing"
                :disabled="isResyncing"
                @click="handleResync"
              />
            </div>

            <!-- Section 1: Basics -->
            <div class="space-y-3">
              <h3
                class="text-xs font-semibold uppercase tracking-wider text-n-slate-9"
              >
                {{ t('CAPTAIN_PRODUCTS.FORM.SECTION_BASICS') }}
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
                  list="category-list"
                />
                <datalist id="category-list">
                  <option
                    v-for="cat in existingCategories"
                    :key="cat"
                    :value="cat"
                  />
                </datalist>
              </div>
            </div>

            <!-- Section 2: Media -->
            <div class="space-y-3">
              <h3
                class="text-xs font-semibold uppercase tracking-wider text-n-slate-9"
              >
                {{ t('CAPTAIN_PRODUCTS.FORM.SECTION_MEDIA') }}
              </h3>
              <div>
                <label class="text-sm text-n-slate-12 block mb-1">
                  {{ t('CAPTAIN_PRODUCTS.FORM.IMAGE_LABEL') }}
                </label>
                <Input
                  v-model="imageUrl"
                  :placeholder="t('CAPTAIN_PRODUCTS.FORM.IMAGE_PLACEHOLDER')"
                  type="url"
                />
                <div
                  v-if="imageUrl"
                  class="mt-2 w-16 h-16 rounded-lg overflow-hidden bg-n-alpha-2"
                >
                  <img
                    :src="imageUrl"
                    :alt="itemName"
                    class="w-full h-full object-cover"
                    @error="$event.target.style.display = 'none'"
                  />
                </div>
              </div>
            </div>

            <!-- Section 3: Pricing & Stock -->
            <div class="space-y-3">
              <h3
                class="text-xs font-semibold uppercase tracking-wider text-n-slate-9"
              >
                {{ t('CAPTAIN_PRODUCTS.FORM.SECTION_PRICING') }}
              </h3>
              <div class="flex gap-3">
                <div class="w-24">
                  <label class="text-sm text-n-slate-12 block mb-1">
                    {{ t('CAPTAIN_PRODUCTS.FORM.CURRENCY_LABEL') }}
                  </label>
                  <select v-model="currency" class="!mb-0">
                    <option v-for="c in currencies" :key="c" :value="c">
                      {{ c }}
                    </option>
                  </select>
                </div>
                <div class="flex-1">
                  <label class="text-sm text-n-slate-12 block mb-1">
                    {{ t('CAPTAIN_PRODUCTS.FORM.PRICE_LABEL') }}
                    <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
                    <span class="text-r-500">*</span>
                  </label>
                  <Input
                    v-model="price"
                    type="number"
                    :placeholder="t('CAPTAIN_PRODUCTS.FORM.PRICE_PLACEHOLDER')"
                    min="0"
                    step="0.01"
                    :class="{ 'border-r-500': errors.price }"
                  />
                  <span
                    v-if="errors.price"
                    class="text-xs text-r-500 mt-0.5 block"
                  >
                    {{ errors.price }}
                  </span>
                </div>
              </div>
              <div>
                <label class="text-sm text-n-slate-12 block mb-1">
                  {{ t('CAPTAIN_PRODUCTS.FORM.STOCK_LABEL') }}
                </label>
                <Input
                  v-model="stockQty"
                  type="number"
                  :placeholder="t('CAPTAIN_PRODUCTS.FORM.STOCK_PLACEHOLDER')"
                  min="0"
                />
              </div>
            </div>

            <!-- Section 4: Description -->
            <div class="space-y-3">
              <h3
                class="text-xs font-semibold uppercase tracking-wider text-n-slate-9"
              >
                {{ t('CAPTAIN_PRODUCTS.FORM.SECTION_DESCRIPTION') }}
              </h3>
              <textarea
                v-model="description"
                :placeholder="
                  t('CAPTAIN_PRODUCTS.FORM.DESCRIPTION_PLACEHOLDER')
                "
                rows="4"
                class="!mb-0 !h-auto resize-none"
              />
              <p class="text-xs text-n-slate-9">
                {{ t('CAPTAIN_PRODUCTS.FORM.DESCRIPTION_HINT') }}
              </p>
            </div>

            <!-- Section 5: Variants (collapsible) -->
            <div class="space-y-3">
              <button
                class="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-n-slate-9 hover:text-n-slate-12"
                @click="showVariants = !showVariants"
              >
                <span
                  class="i-lucide-chevron-right w-3.5 h-3.5 transition-transform"
                  :class="{ 'rotate-90': showVariants }"
                />
                <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
                {{ t('CAPTAIN_PRODUCTS.FORM.SECTION_VARIANTS') }}
                <span v-if="variants.length" class="text-n-slate-10">
                  ({{ variants.length }})
                </span>
              </button>
              <div v-if="showVariants" class="space-y-2 pl-5">
                <div
                  v-for="(variant, i) in variants"
                  :key="i"
                  class="flex gap-2 items-start"
                >
                  <Input
                    v-model="variant.item_name"
                    :placeholder="
                      t('CAPTAIN_PRODUCTS.FORM.VARIANT_NAME_PLACEHOLDER')
                    "
                    class="flex-1"
                  />
                  <Input
                    v-model="variant.item_code"
                    :placeholder="
                      t('CAPTAIN_PRODUCTS.FORM.VARIANT_SKU_PLACEHOLDER')
                    "
                    class="w-28 font-mono"
                  />
                  <Input
                    v-model="variant.price"
                    type="number"
                    :placeholder="
                      t('CAPTAIN_PRODUCTS.FORM.VARIANT_PRICE_PLACEHOLDER')
                    "
                    class="w-24"
                    min="0"
                    step="0.01"
                  />
                  <button
                    class="p-1.5 rounded hover:bg-r-50 text-n-slate-9 hover:text-r-500 shrink-0 mt-1"
                    @click="removeVariant(i)"
                  >
                    <span class="i-lucide-trash-2 w-4 h-4" />
                  </button>
                </div>
                <button
                  class="text-xs text-b-600 hover:text-b-700 font-medium"
                  @click="addVariant"
                >
                  <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
                  + {{ t('CAPTAIN_PRODUCTS.FORM.ADD_VARIANT') }}
                </button>
              </div>
            </div>

            <!-- Section 6: Specifications (collapsible) -->
            <div class="space-y-3">
              <button
                class="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-n-slate-9 hover:text-n-slate-12"
                @click="showSpecs = !showSpecs"
              >
                <span
                  class="i-lucide-chevron-right w-3.5 h-3.5 transition-transform"
                  :class="{ 'rotate-90': showSpecs }"
                />
                <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
                {{ t('CAPTAIN_PRODUCTS.FORM.SECTION_SPECS') }}
                <span v-if="specs.length" class="text-n-slate-10">
                  ({{ specs.length }})
                </span>
              </button>
              <div v-if="showSpecs" class="space-y-2 pl-5">
                <div
                  v-for="(spec, i) in specs"
                  :key="i"
                  class="flex gap-2 items-start"
                >
                  <Input
                    v-model="spec.label"
                    :placeholder="
                      t('CAPTAIN_PRODUCTS.FORM.SPEC_KEY_PLACEHOLDER')
                    "
                    class="flex-1"
                  />
                  <Input
                    v-model="spec.value"
                    :placeholder="
                      t('CAPTAIN_PRODUCTS.FORM.SPEC_VALUE_PLACEHOLDER')
                    "
                    class="flex-1"
                  />
                  <button
                    class="p-1.5 rounded hover:bg-r-50 text-n-slate-9 hover:text-r-500 shrink-0 mt-1"
                    @click="removeSpec(i)"
                  >
                    <span class="i-lucide-trash-2 w-4 h-4" />
                  </button>
                </div>
                <button
                  class="text-xs text-b-600 hover:text-b-700 font-medium"
                  @click="addSpec"
                >
                  <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
                  + {{ t('CAPTAIN_PRODUCTS.FORM.ADD_SPEC') }}
                </button>
              </div>
            </div>

            <!-- Section 7: What Captain sees (edit mode only) -->
            <div v-if="isEditing" class="space-y-3">
              <button
                class="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-n-slate-9 hover:text-n-slate-12"
                @click="showCaptainPreview = !showCaptainPreview"
              >
                <span
                  class="i-lucide-chevron-right w-3.5 h-3.5 transition-transform"
                  :class="{ 'rotate-90': showCaptainPreview }"
                />
                {{ t('CAPTAIN_PRODUCTS.FORM.SECTION_CAPTAIN_PREVIEW') }}
              </button>
              <div v-if="showCaptainPreview" class="pl-5">
                <pre
                  v-if="product?.formatted_text"
                  class="text-xs font-mono whitespace-pre-wrap bg-n-alpha-2 rounded-lg p-3 text-n-slate-11 max-h-64 overflow-y-auto"
                  >{{ product.formatted_text }}</pre
                >
                <p v-else class="text-xs text-n-slate-9 italic">
                  {{ t('CAPTAIN_PRODUCTS.FORM.CAPTAIN_PREVIEW_EMPTY') }}
                </p>
              </div>
            </div>
          </div>

          <!-- Footer -->
          <div
            class="px-6 py-4 border-t border-n-slate-3 flex items-center gap-3"
          >
            <Button
              :label="t('CAPTAIN_PRODUCTS.FORM.CANCEL')"
              color="slate"
              variant="faded"
              @click="handleClose"
            />
            <Button
              v-if="isEditing"
              :label="t('CAPTAIN_PRODUCTS.FORM.DELETE')"
              color="ruby"
              variant="faded"
              @click="handleDelete"
            />
            <div class="flex-1" />
            <Button
              :label="
                isEditing
                  ? t('CAPTAIN_PRODUCTS.FORM.SAVE_CHANGES')
                  : t('CAPTAIN_PRODUCTS.FORM.SAVE')
              "
              :disabled="!canSave || isSaving"
              :is-loading="isSaving"
              @click="handleSave"
            />
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>

  <!-- Discard confirmation dialog -->
  <Dialog
    ref="discardDialogRef"
    type="alert"
    :title="t('CAPTAIN_PRODUCTS.FORM.DISCARD_TITLE')"
    :description="t('CAPTAIN_PRODUCTS.FORM.DISCARD_MESSAGE')"
    :confirm-button-label="t('CAPTAIN_PRODUCTS.FORM.DISCARD_CONFIRM')"
    @confirm="handleDiscard"
  />

  <!-- Delete confirmation dialog -->
  <Dialog
    ref="deleteDialogRef"
    type="alert"
    :title="t('CAPTAIN_PRODUCTS.FORM.DELETE_TITLE')"
    :description="
      t('CAPTAIN_PRODUCTS.FORM.DELETE_DESCRIPTION', {
        name: product?.item_name,
      })
    "
    :confirm-button-label="t('CAPTAIN_PRODUCTS.FORM.DELETE_CONFIRM')"
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
</template>

<style scoped>
.slide-enter-active,
.slide-leave-active {
  transition: all 0.2s ease-out;
}

.slide-enter-from .relative,
.slide-leave-to .relative {
  transform: translateX(100%);
}

.slide-enter-from .absolute,
.slide-leave-to .absolute {
  opacity: 0;
}
</style>
