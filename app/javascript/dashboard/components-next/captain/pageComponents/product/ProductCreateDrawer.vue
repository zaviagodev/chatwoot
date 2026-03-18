<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  isOpen: { type: Boolean, default: false },
  assistantId: { type: Number, required: true },
  existingCategories: { type: Array, default: () => [] },
});

const emit = defineEmits(['close', 'saved']);
const store = useStore();
const { t } = useI18n();

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

const isSaving = ref(false);
const errors = ref({});
const discardDialogRef = ref(null);

const isDirty = computed(
  () =>
    !!(
      itemName.value ||
      itemCode.value ||
      itemGroup.value ||
      price.value ||
      stockQty.value ||
      description.value ||
      imageUrl.value
    )
);

const canSave = computed(
  () => itemName.value.trim() && price.value && Number(price.value) > 0
);

// Reset form when drawer opens
watch(
  () => props.isOpen,
  open => {
    if (open) {
      errors.value = {};
      itemName.value = '';
      itemCode.value = '';
      itemGroup.value = '';
      status.value = 'active';
      imageUrl.value = '';
      currency.value = 'THB';
      price.value = '';
      stockQty.value = '';
      description.value = '';
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

const handleSave = async () => {
  if (!validate()) return;
  isSaving.value = true;

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
    description_source: 'manual',
  };

  try {
    await store.dispatch('captainProducts/create', payload);
    useAlert(t('CAPTAIN_PRODUCTS.FORM.TOAST_CREATED'));
    emit('saved');
  } catch {
    useAlert(t('CAPTAIN_PRODUCTS.FORM.TOAST_CREATE_ERROR'));
  }
  isSaving.value = false;
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
              {{ t('CAPTAIN_PRODUCTS.FORM.ADD_TITLE') }}
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
            <div class="flex-1" />
            <Button
              :label="t('CAPTAIN_PRODUCTS.FORM.SAVE')"
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
