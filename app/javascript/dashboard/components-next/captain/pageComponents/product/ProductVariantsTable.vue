<script setup>
import { ref, computed, watch, nextTick, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { vOnClickOutside } from '@vueuse/components';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  variants: { type: Array, default: () => [] },
  parentPrice: { type: [String, Number], default: null },
  optionGroups: { type: Array, default: () => [] },
});

const emit = defineEmits(['add', 'remove', 'update:variant', 'manage-options']);
const { t } = useI18n();
const route = useRoute();
const router = useRouter();

// --- Option summary ---
const optionSummary = computed(() => {
  if (!props.optionGroups?.length) return '';
  return props.optionGroups
    .filter(g => g.name && g.values?.length)
    .map(g => `${g.name}: ${g.values.join(', ')}`)
    .join(' · ');
});

// --- Sorting: attach _originalIndex to each variant ---
const sortedVariants = computed(() => {
  const indexed = props.variants.map((v, i) => ({ ...v, _originalIndex: i }));
  if (!props.optionGroups?.length) return indexed;
  return indexed.sort((a, b) => {
    const diff = props.optionGroups.reduce((result, group) => {
      if (result !== 0) return result;
      const aVal = a.attributes?.find(
        attr => attr.attribute === group.name
      )?.value;
      const bVal = b.attributes?.find(
        attr => attr.attribute === group.name
      )?.value;
      const aIdx = group.values?.indexOf(aVal) ?? -1;
      const bIdx = group.values?.indexOf(bVal) ?? -1;
      return aIdx - bIdx;
    }, 0);
    return diff;
  });
});

// --- Navigation ---
const canEditVariant = variant =>
  !!route.params.productId && !!variant.item_code;

const navigateToVariant = index => {
  router.push({
    name: 'captain_variant_detail',
    params: { ...route.params, variantIndex: index },
  });
};

// --- Image popover (declared early — used in startEdit) ---
const imagePopoverRow = ref(null);

// --- Inline editing state ---
const editingCell = ref(null); // { row: number, col: string } | null
const editValue = ref('');
const editInputRef = ref(null);
let commitSource = null; // 'keyboard' | null — blur guard (Gotcha #13)

const EDITABLE_COLS = ['item_name', 'item_code', 'price', 'stock_qty'];

const startEdit = (originalIndex, col, currentValue) => {
  commitSource = null;
  imagePopoverRow.value = null;
  editingCell.value = { row: originalIndex, col };
  editValue.value = currentValue != null ? String(currentValue) : '';
  nextTick(() => {
    editInputRef.value?.focus();
    editInputRef.value?.select();
  });
};

const commitEdit = () => {
  if (!editingCell.value) return;
  const { row, col } = editingCell.value;
  let value = editValue.value;
  if (col === 'price') {
    value = value !== '' ? Number(value) : props.variants[row]?.price;
  } else if (col === 'stock_qty') {
    value = value !== '' ? Number(value) : null;
  }
  emit('update:variant', { index: row, field: col, value });
  editingCell.value = null;
};

const cancelEdit = () => {
  editingCell.value = null;
};

const handleBlur = () => {
  if (commitSource === 'keyboard') {
    commitSource = null;
    return;
  }
  commitEdit();
};

const handleEditKeydown = e => {
  if (e.key === 'Enter') {
    e.preventDefault();
    commitSource = 'keyboard';
    commitEdit();
  } else if (e.key === 'Escape') {
    e.stopPropagation();
    commitSource = 'keyboard';
    cancelEdit();
  } else if (e.key === 'Tab') {
    e.preventDefault();
    commitSource = 'keyboard';
    if (!editingCell.value) return;
    const { row, col } = editingCell.value;
    commitEdit();
    const colIdx = EDITABLE_COLS.indexOf(col);
    const nextCol = e.shiftKey ? colIdx - 1 : colIdx + 1;
    if (nextCol >= 0 && nextCol < EDITABLE_COLS.length) {
      const variant = props.variants[row];
      const field = EDITABLE_COLS[nextCol];
      startEdit(row, field, variant[field]);
    }
  }
};

// --- Image popover (continued) ---
const imagePopoverUrl = ref('');
const debouncedPopoverUrl = ref('');
let popoverDebounceTimer = null;

const openImagePopover = (originalIndex, currentUrl) => {
  editingCell.value = null;
  imagePopoverRow.value = originalIndex;
  imagePopoverUrl.value = currentUrl || '';
  debouncedPopoverUrl.value = currentUrl || '';
};

const closeImagePopover = () => {
  if (imagePopoverRow.value == null) return;
  const idx = imagePopoverRow.value;
  if (imagePopoverUrl.value !== (props.variants[idx]?.image || '')) {
    emit('update:variant', {
      index: idx,
      field: 'image',
      value: imagePopoverUrl.value,
    });
  }
  imagePopoverRow.value = null;
};

watch(imagePopoverUrl, val => {
  clearTimeout(popoverDebounceTimer);
  popoverDebounceTimer = setTimeout(() => {
    debouncedPopoverUrl.value = val;
  }, 500);
});

onUnmounted(() => {
  clearTimeout(popoverDebounceTimer);
});

// --- Helpers ---
const isValidImageUrl = url => {
  if (!url) return false;
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
};

const isCustomPrice = variant => {
  if (variant.price == null || variant.price === '') return false;
  if (props.parentPrice == null || props.parentPrice === '') return false;
  return Number(variant.price) !== Number(props.parentPrice);
};

const isEditing = (originalIndex, col) => {
  return (
    editingCell.value?.row === originalIndex && editingCell.value?.col === col
  );
};
</script>

<template>
  <div class="space-y-3">
    <div class="flex items-center justify-between">
      <h3 class="text-xs font-semibold uppercase tracking-wider text-n-slate-9">
        {{ t('CAPTAIN_PRODUCTS.DETAIL.SECTION_VARIANTS') }}
        <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
        <span v-if="variants.length" class="text-n-slate-10 ml-1">
          ({{ variants.length }})
        </span>
      </h3>
      <div class="flex items-center gap-2">
        <button
          class="text-xs text-b-600 hover:text-b-700 font-medium"
          @click="emit('manage-options')"
        >
          {{ t('CAPTAIN_PRODUCTS.OPTION_GROUPS.MANAGE_OPTIONS') }}
        </button>
        <button
          class="text-xs text-b-600 hover:text-b-700 font-medium"
          @click="emit('add')"
        >
          <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
          + {{ t('CAPTAIN_PRODUCTS.DETAIL.ADD_VARIANT') }}
        </button>
      </div>
    </div>

    <!-- Option summary line -->
    <p v-if="optionSummary" class="text-sm text-n-slate-9">
      {{ optionSummary }}
    </p>

    <!-- Variant table -->
    <div v-if="variants.length" class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-n-slate-3">
            <th
              scope="col"
              class="text-left py-2 pr-2 text-xs font-medium text-n-slate-10 w-12"
            >
              {{ t('CAPTAIN_PRODUCTS.TABLE.ENABLED') }}
            </th>
            <th
              scope="col"
              class="text-left py-2 pr-2 text-xs font-medium text-n-slate-10 w-12"
            >
              {{ t('CAPTAIN_PRODUCTS.TABLE.IMAGE') }}
            </th>
            <th
              scope="col"
              class="text-left py-2 pr-3 text-xs font-medium text-n-slate-10"
            >
              {{ t('CAPTAIN_PRODUCTS.TABLE.NAME') }}
            </th>
            <th
              scope="col"
              class="text-left py-2 pr-3 text-xs font-medium text-n-slate-10 w-32"
            >
              {{ t('CAPTAIN_PRODUCTS.TABLE.ATTRIBUTES') }}
            </th>
            <th
              scope="col"
              class="text-left py-2 pr-3 text-xs font-medium text-n-slate-10 w-28"
            >
              {{ t('CAPTAIN_PRODUCTS.FORM.SKU_LABEL') }}
            </th>
            <th
              scope="col"
              class="text-left py-2 pr-3 text-xs font-medium text-n-slate-10 w-28"
            >
              {{ t('CAPTAIN_PRODUCTS.FORM.PRICE_LABEL') }}
            </th>
            <th
              scope="col"
              class="text-left py-2 pr-3 text-xs font-medium text-n-slate-10 w-20"
            >
              {{ t('CAPTAIN_PRODUCTS.TABLE.STOCK') }}
            </th>
            <th scope="col" class="w-16" />
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="variant in sortedVariants"
            :key="variant._originalIndex"
            class="border-b border-n-slate-2 hover:bg-n-alpha-1 group transition-opacity duration-200"
            :class="{ 'opacity-50': variant.enabled === false }"
          >
            <!-- Enabled toggle -->
            <td class="py-2 pr-2">
              <Switch
                :model-value="variant.enabled !== false"
                :aria-label="
                  variant.enabled !== false
                    ? t('CAPTAIN_PRODUCTS.VARIANTS.TOGGLE_ARIA_DISABLE', {
                        name: variant.item_name,
                      })
                    : t('CAPTAIN_PRODUCTS.VARIANTS.TOGGLE_ARIA_ENABLE', {
                        name: variant.item_name,
                      })
                "
                @update:model-value="
                  emit('update:variant', {
                    index: variant._originalIndex,
                    field: 'enabled',
                    value: $event,
                  })
                "
              />
            </td>

            <!-- Image thumbnail + popover -->
            <td class="py-2 pr-2 relative">
              <div
                class="w-8 h-8 rounded overflow-hidden bg-n-alpha-2 flex items-center justify-center cursor-pointer"
                @click="openImagePopover(variant._originalIndex, variant.image)"
              >
                <img
                  v-if="isValidImageUrl(variant.image)"
                  :src="variant.image"
                  :alt="variant.item_name"
                  class="w-full h-full object-cover"
                  @error="$event.target.classList.add('hidden')"
                />
                <span
                  v-else
                  class="i-lucide-image w-3.5 h-3.5 text-n-slate-7"
                />
              </div>
              <!-- Image popover -->
              <div
                v-if="imagePopoverRow === variant._originalIndex"
                v-on-click-outside="closeImagePopover"
                class="absolute top-full left-0 mt-1 z-50 w-52 bg-n-surface-1 border border-n-slate-3 rounded-lg shadow-lg p-3 space-y-2"
                role="dialog"
                :aria-label="t('CAPTAIN_PRODUCTS.TABLE.IMAGE_POPOVER_TITLE')"
              >
                <div
                  class="w-[120px] h-[120px] rounded bg-n-alpha-2 overflow-hidden mx-auto"
                >
                  <img
                    v-if="isValidImageUrl(debouncedPopoverUrl)"
                    :src="debouncedPopoverUrl"
                    class="w-full h-full object-cover"
                    @error="$event.target.classList.add('hidden')"
                  />
                  <div
                    v-else
                    class="w-full h-full flex items-center justify-center"
                  >
                    <span class="i-lucide-image w-6 h-6 text-n-slate-7" />
                  </div>
                </div>
                <input
                  v-model="imagePopoverUrl"
                  type="url"
                  :placeholder="
                    t('CAPTAIN_PRODUCTS.TABLE.IMAGE_POPOVER_URL_PLACEHOLDER')
                  "
                  class="w-full border border-n-slate-4 rounded px-2 py-1 text-xs bg-n-surface-1 outline-none focus:ring-1 focus:ring-b-500"
                />
              </div>
            </td>

            <!-- Name (click-to-edit) -->
            <td class="py-2 pr-3">
              <input
                v-if="isEditing(variant._originalIndex, 'item_name')"
                ref="editInputRef"
                v-model="editValue"
                class="w-full border border-b-500 rounded px-2 py-1 text-sm bg-n-surface-1 outline-none ring-1 ring-b-500"
                :aria-label="
                  t('CAPTAIN_PRODUCTS.TABLE.EDITING_CELL_ARIA', {
                    field: t('CAPTAIN_PRODUCTS.TABLE.NAME'),
                    name: variant.item_name,
                  })
                "
                @blur="handleBlur"
                @keydown="handleEditKeydown"
              />
              <span
                v-else
                class="block truncate text-sm text-n-slate-12 cursor-pointer hover:bg-n-alpha-1 rounded px-2 py-1 -mx-2 -my-1"
                role="button"
                tabindex="0"
                :aria-label="
                  t('CAPTAIN_PRODUCTS.TABLE.EDIT_CELL_ARIA', {
                    field: t('CAPTAIN_PRODUCTS.TABLE.NAME'),
                    name: variant.item_name,
                  })
                "
                @click="
                  startEdit(
                    variant._originalIndex,
                    'item_name',
                    variant.item_name
                  )
                "
                @keydown.enter="
                  startEdit(
                    variant._originalIndex,
                    'item_name',
                    variant.item_name
                  )
                "
              >
                {{
                  variant.item_name ||
                  t('CAPTAIN_PRODUCTS.FORM.VARIANT_NAME_PLACEHOLDER')
                }}
              </span>
            </td>

            <!-- Attribute pills -->
            <td class="py-2 pr-3">
              <div class="flex flex-wrap gap-1">
                <span
                  v-for="attr in variant.attributes"
                  :key="attr.attribute"
                  class="inline-flex items-center px-1.5 py-0.5 rounded text-xs bg-n-alpha-2 text-n-slate-11"
                >
                  {{ attr.value }}
                </span>
              </div>
            </td>

            <!-- SKU (click-to-edit) -->
            <td class="py-2 pr-3">
              <input
                v-if="isEditing(variant._originalIndex, 'item_code')"
                ref="editInputRef"
                v-model="editValue"
                class="w-full border border-b-500 rounded px-2 py-1 text-sm font-mono bg-n-surface-1 outline-none ring-1 ring-b-500"
                :aria-label="
                  t('CAPTAIN_PRODUCTS.TABLE.EDITING_CELL_ARIA', {
                    field: t('CAPTAIN_PRODUCTS.FORM.SKU_LABEL'),
                    name: variant.item_name,
                  })
                "
                @blur="handleBlur"
                @keydown="handleEditKeydown"
              />
              <span
                v-else
                class="block truncate text-sm text-n-slate-12 font-mono cursor-pointer hover:bg-n-alpha-1 rounded px-2 py-1 -mx-2 -my-1"
                role="button"
                tabindex="0"
                :aria-label="
                  t('CAPTAIN_PRODUCTS.TABLE.EDIT_CELL_ARIA', {
                    field: t('CAPTAIN_PRODUCTS.FORM.SKU_LABEL'),
                    name: variant.item_name,
                  })
                "
                @click="
                  startEdit(
                    variant._originalIndex,
                    'item_code',
                    variant.item_code
                  )
                "
                @keydown.enter="
                  startEdit(
                    variant._originalIndex,
                    'item_code',
                    variant.item_code
                  )
                "
              >
                {{
                  variant.item_code ||
                  t('CAPTAIN_PRODUCTS.FORM.VARIANT_SKU_PLACEHOLDER')
                }}
              </span>
            </td>

            <!-- Price (click-to-edit) + custom badge -->
            <td class="py-2 pr-3">
              <input
                v-if="isEditing(variant._originalIndex, 'price')"
                ref="editInputRef"
                v-model="editValue"
                type="number"
                step="0.01"
                min="0"
                class="w-full border border-b-500 rounded px-2 py-1 text-sm bg-n-surface-1 outline-none ring-1 ring-b-500"
                :aria-label="
                  t('CAPTAIN_PRODUCTS.TABLE.EDITING_CELL_ARIA', {
                    field: t('CAPTAIN_PRODUCTS.FORM.PRICE_LABEL'),
                    name: variant.item_name,
                  })
                "
                @blur="handleBlur"
                @keydown="handleEditKeydown"
              />
              <span
                v-else
                class="inline-flex items-center text-sm text-n-slate-12 cursor-pointer hover:bg-n-alpha-1 rounded px-2 py-1 -mx-2 -my-1"
                role="button"
                tabindex="0"
                :aria-label="
                  t('CAPTAIN_PRODUCTS.TABLE.EDIT_CELL_ARIA', {
                    field: t('CAPTAIN_PRODUCTS.FORM.PRICE_LABEL'),
                    name: variant.item_name,
                  })
                "
                @click="
                  startEdit(variant._originalIndex, 'price', variant.price)
                "
                @keydown.enter="
                  startEdit(variant._originalIndex, 'price', variant.price)
                "
              >
                {{
                  variant.price ||
                  t('CAPTAIN_PRODUCTS.FORM.VARIANT_PRICE_PLACEHOLDER')
                }}
                <span
                  v-if="isCustomPrice(variant)"
                  class="ml-1 text-xs text-n-amber-11 bg-n-amber-2 rounded px-1"
                >
                  {{ t('CAPTAIN_PRODUCTS.VARIANTS.CUSTOM_PRICE') }}
                </span>
              </span>
            </td>

            <!-- Stock (click-to-edit) -->
            <td class="py-2 pr-3">
              <input
                v-if="isEditing(variant._originalIndex, 'stock_qty')"
                ref="editInputRef"
                v-model="editValue"
                type="number"
                min="0"
                class="w-full border border-b-500 rounded px-2 py-1 text-sm bg-n-surface-1 outline-none ring-1 ring-b-500"
                :aria-label="
                  t('CAPTAIN_PRODUCTS.TABLE.EDITING_CELL_ARIA', {
                    field: t('CAPTAIN_PRODUCTS.TABLE.STOCK'),
                    name: variant.item_name,
                  })
                "
                @blur="handleBlur"
                @keydown="handleEditKeydown"
              />
              <span
                v-else
                class="block text-xs cursor-pointer hover:bg-n-alpha-1 rounded px-2 py-1 -mx-2 -my-1"
                :class="{
                  'text-n-slate-9': variant.stock_qty == null,
                  'text-n-amber-11':
                    Number(variant.stock_qty) === 0 &&
                    variant.stock_qty != null,
                  'text-n-slate-11':
                    variant.stock_qty != null &&
                    Number(variant.stock_qty) !== 0,
                }"
                role="button"
                tabindex="0"
                :aria-label="
                  t('CAPTAIN_PRODUCTS.TABLE.EDIT_CELL_ARIA', {
                    field: t('CAPTAIN_PRODUCTS.TABLE.STOCK'),
                    name: variant.item_name,
                  })
                "
                @click="
                  startEdit(
                    variant._originalIndex,
                    'stock_qty',
                    variant.stock_qty
                  )
                "
                @keydown.enter="
                  startEdit(
                    variant._originalIndex,
                    'stock_qty',
                    variant.stock_qty
                  )
                "
              >
                <template v-if="variant.stock_qty == null">
                  {{ t('CAPTAIN_PRODUCTS.TABLE.STOCK_NONE') }}
                </template>
                <template v-else-if="Number(variant.stock_qty) === 0">
                  {{ t('CAPTAIN_PRODUCTS.TABLE.STOCK_OUT') }}
                </template>
                <template v-else>
                  {{ variant.stock_qty }}
                </template>
              </span>
            </td>

            <!-- Actions -->
            <td class="py-2">
              <div class="flex items-center gap-1">
                <button
                  class="p-1.5 rounded opacity-0 group-hover:opacity-100 transition-opacity"
                  :class="
                    canEditVariant(variant)
                      ? 'hover:bg-n-alpha-2 text-n-slate-9 hover:text-n-slate-12 cursor-pointer'
                      : 'text-n-slate-6 cursor-not-allowed'
                  "
                  :title="
                    canEditVariant(variant)
                      ? ''
                      : t('CAPTAIN_PRODUCTS.DETAIL.SAVE_BEFORE_EDIT')
                  "
                  :disabled="!canEditVariant(variant)"
                  @click="
                    canEditVariant(variant) &&
                      navigateToVariant(variant._originalIndex)
                  "
                >
                  <span class="i-lucide-pencil w-4 h-4" />
                </button>
                <button
                  class="p-1.5 rounded hover:bg-r-50 text-n-slate-9 hover:text-r-500 opacity-0 group-hover:opacity-100 transition-opacity"
                  @click="emit('remove', variant._originalIndex)"
                >
                  <span class="i-lucide-trash-2 w-4 h-4" />
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Empty variants -->
    <div v-else class="py-6 text-center space-y-3">
      <span class="i-lucide-layers w-8 h-8 text-n-slate-7 mx-auto block" />
      <p class="text-sm text-n-slate-10">
        {{ t('CAPTAIN_PRODUCTS.OPTION_GROUPS.EMPTY_TITLE') }}
      </p>
      <p class="text-xs text-n-slate-9">
        {{ t('CAPTAIN_PRODUCTS.OPTION_GROUPS.EMPTY_SUBTITLE') }}
      </p>
      <div class="flex items-center justify-center gap-2">
        <button
          class="text-sm text-b-600 hover:text-b-700 font-medium px-3 py-1.5 rounded-lg border border-b-200 hover:bg-b-50"
          @click="emit('manage-options')"
        >
          {{ t('CAPTAIN_PRODUCTS.OPTION_GROUPS.DEFINE_OPTIONS') }}
        </button>
        <button
          class="text-sm text-n-slate-10 hover:text-n-slate-12 font-medium px-3 py-1.5"
          @click="emit('add')"
        >
          {{ t('CAPTAIN_PRODUCTS.DETAIL.ADD_VARIANT') }}
        </button>
      </div>
    </div>
  </div>
</template>
