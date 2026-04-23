<script setup>
import { ref, computed, nextTick } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CaptainErpProxy from 'dashboard/api/captain/erpProxy';
import CaptainProductsAPI from 'dashboard/api/captain/products';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
  existingProducts: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close']);
const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const searchQuery = ref('');
const selectedItemGroup = ref('');
const searchResults = ref([]);
const itemGroups = ref([]);
const selectedItems = ref(new Set());
const isSearching = ref(false);
const isLoadingMore = ref(false);
const isAdding = ref(false);
const hasSearched = ref(false);
const currentPage = ref(1);
const totalItems = ref(0);

// Setup state
const showSetup = ref(false);
const setupCompany = ref('');
const setupWarehouse = ref('');
const isSavingSetup = ref(false);

const PAGE_SIZE = 100;

// Fetch ALL existing item_codes from server (not just the paginated prop)
// to prevent 422 duplicate errors when assistant has more products than one page
const existingItemCodes = ref(
  new Set(props.existingProducts.map(p => p.item_code))
);

const fetchExistingItemCodes = async () => {
  try {
    const { data } = await CaptainProductsAPI.getExistingItemCodes({
      assistantId: props.assistantId,
    });
    const codes = data.item_codes || [];
    existingItemCodes.value = new Set(codes);
  } catch {
    // Fallback to prop-based list if endpoint fails
  }
};

const isItemAdded = itemCode => existingItemCodes.value.has(itemCode);

const selectedCount = computed(() => selectedItems.value.size);

const hasMoreItems = computed(
  () => searchResults.value.length < totalItems.value
);

// Selectable items = visible items that aren't already added
const selectableItems = computed(() =>
  searchResults.value.filter(item => !isItemAdded(item.item_code))
);

const allSelectableChecked = computed(
  () =>
    selectableItems.value.length > 0 &&
    selectableItems.value.every(item => selectedItems.value.has(item.item_code))
);

const someSelectableChecked = computed(
  () =>
    !allSelectableChecked.value &&
    selectableItems.value.some(item => selectedItems.value.has(item.item_code))
);

const toggleSelection = itemCode => {
  if (isItemAdded(itemCode)) return;
  const newSet = new Set(selectedItems.value);
  if (newSet.has(itemCode)) {
    newSet.delete(itemCode);
  } else {
    newSet.add(itemCode);
  }
  selectedItems.value = newSet;
};

const toggleSelectAll = () => {
  const newSet = new Set(selectedItems.value);
  if (allSelectableChecked.value) {
    // Deselect all visible selectable items
    selectableItems.value.forEach(item => newSet.delete(item.item_code));
  } else {
    // Select all visible selectable items
    selectableItems.value.forEach(item => newSet.add(item.item_code));
  }
  selectedItems.value = newSet;
};

const searchProducts = async (page = 1, append = false) => {
  if (!append) {
    isSearching.value = true;
  } else {
    isLoadingMore.value = true;
  }
  hasSearched.value = true;
  try {
    const { data } = await CaptainErpProxy.searchProducts({
      query: searchQuery.value,
      itemGroup: selectedItemGroup.value,
      page,
      pageSize: PAGE_SIZE,
      assistantId: props.assistantId,
    });
    const items = data.products || data.data || data || [];
    const parsed = Array.isArray(items) ? items : [];
    if (append) {
      searchResults.value = [...searchResults.value, ...parsed];
    } else {
      searchResults.value = parsed;
    }
    totalItems.value = data.total ?? parsed.length;
    currentPage.value = page;
  } catch {
    if (!append) searchResults.value = [];
    useAlert(t('CAPTAIN_PRODUCTS.TOAST.SYNC_ERROR'));
  } finally {
    isSearching.value = false;
    isLoadingMore.value = false;
  }
};

const loadMore = () => {
  if (isLoadingMore.value || !hasMoreItems.value) return;
  searchProducts(currentPage.value + 1, true);
};

const debouncedSearch = debounce(() => {
  searchProducts();
}, 300);

const fetchItemGroups = async () => {
  try {
    const { data } = await CaptainErpProxy.getItemGroups({
      assistantId: props.assistantId,
    });
    const groups = data.item_groups || data.data || data || [];
    itemGroups.value = Array.isArray(groups) ? groups : [];
  } catch {
    itemGroups.value = [];
  }
};

const handleFilterChange = () => {
  searchProducts();
};

// Fetch full product detail for ALL selected items (not just variant items).
// search_products only returns name/price/category — product_detail adds
// stock_qty, specs, variants, formatted_text, and long_description.
const enrichWithDetail = async item => {
  try {
    const { data } = await CaptainErpProxy.getProductDetail({
      assistantId: props.assistantId,
      itemCode: item.item_code,
    });
    const detail = data.data || data;
    return {
      ...item,
      description:
        detail.long_description || detail.description || item.description,
      variants: detail.variants || [],
      specs: detail.specs || item.specs || [],
      formatted_text: data.formatted_text || item.formatted_text,
      stock_qty: detail.stock_qty ?? item.stock_qty,
      price: detail.price ?? item.price,
      image: detail.image || item.image,
      currency: detail.currency || item.currency,
    };
  } catch {
    return item;
  }
};

const handleAddSelected = async () => {
  if (selectedCount.value === 0) return;
  isAdding.value = true;

  const itemsToAdd = searchResults.value.filter(item =>
    selectedItems.value.has(item.item_code)
  );

  // Enrich all items with full detail from Workspace (stock, specs, variants)
  const enrichedItems = await Promise.all(itemsToAdd.map(enrichWithDetail));

  const results = await Promise.allSettled(
    enrichedItems.map(item =>
      store.dispatch('captainProducts/create', {
        assistantId: props.assistantId,
        item_code: item.item_code,
        item_name: item.item_name,
        description: item.description,
        price: item.price,
        currency: item.currency,
        stock_qty: item.stock_qty,
        item_group: item.item_group,
        image: item.image,
        variants: item.variants,
        specs: item.specs,
        formatted_text: item.formatted_text,
      })
    )
  );

  const succeeded = results.filter(r => r.status === 'fulfilled').length;
  const failed = results.filter(r => r.status === 'rejected').length;

  // Mark successfully added items as existing so they show "Already added"
  if (succeeded > 0) {
    const newCodes = new Set(existingItemCodes.value);
    results.forEach((r, i) => {
      if (r.status === 'fulfilled') newCodes.add(itemsToAdd[i].item_code);
    });
    existingItemCodes.value = newCodes;

    const msg =
      succeeded === 1
        ? t('CAPTAIN_PRODUCTS.TOAST.ADDED')
        : t('CAPTAIN_PRODUCTS.TOAST.ADDED_MULTIPLE', { count: succeeded });
    useAlert(msg);
  }

  if (failed > 0) {
    useAlert(t('CAPTAIN_PRODUCTS.TOAST.ADD_ERROR'));
  }

  if (failed === 0) {
    dialogRef.value.close();
  } else {
    // Remove succeeded items from selection
    const failedCodes = new Set(
      results
        .map((r, i) =>
          r.status === 'rejected' ? itemsToAdd[i].item_code : null
        )
        .filter(Boolean)
    );
    selectedItems.value = failedCodes;
  }

  isAdding.value = false;
};

const handleSetup = async () => {
  if (!setupCompany.value) return;
  isSavingSetup.value = true;
  try {
    await CaptainErpProxy.setup({
      assistantId: props.assistantId,
      erpCompany: setupCompany.value,
      erpWarehouse: setupWarehouse.value,
    });
    useAlert(t('CAPTAIN_PRODUCTS.TOAST.SETUP_SUCCESS'));
    showSetup.value = false;
    nextTick(() => {
      searchProducts();
      fetchItemGroups();
    });
  } catch {
    useAlert(t('CAPTAIN_PRODUCTS.TOAST.SYNC_ERROR'));
  } finally {
    isSavingSetup.value = false;
  }
};

const handleClose = () => {
  emit('close');
};

const handleOpen = () => {
  fetchExistingItemCodes();
  searchProducts();
  fetchItemGroups();
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="$t('CAPTAIN_PRODUCTS.ADD_DIALOG.TITLE')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    width="3xl"
    overflow-y-auto
    @close="handleClose"
    @vue:mounted="handleOpen"
  >
    <!-- Setup banner -->
    <div
      v-if="showSetup"
      class="flex flex-col gap-3 p-4 mb-4 rounded-lg bg-n-alpha-2"
    >
      <h4 class="text-sm font-medium text-n-slate-12">
        {{ $t('CAPTAIN_PRODUCTS.SETUP.TITLE') }}
      </h4>
      <p class="text-xs text-n-slate-11">
        {{ $t('CAPTAIN_PRODUCTS.SETUP.DESCRIPTION') }}
      </p>
      <div class="flex gap-3">
        <Input
          v-model="setupCompany"
          :placeholder="$t('CAPTAIN_PRODUCTS.SETUP.COMPANY_LABEL')"
          class="flex-1"
        />
        <Input
          v-model="setupWarehouse"
          :placeholder="$t('CAPTAIN_PRODUCTS.SETUP.WAREHOUSE_LABEL')"
          class="flex-1"
        />
        <Button
          :label="$t('CAPTAIN_PRODUCTS.SETUP.SAVE_BUTTON')"
          :is-loading="isSavingSetup"
          :disabled="!setupCompany || isSavingSetup"
          @click="handleSetup"
        />
      </div>
    </div>

    <!-- Search and filter bar -->
    <div class="flex gap-3 mb-4">
      <Input
        v-model="searchQuery"
        type="search"
        :placeholder="$t('CAPTAIN_PRODUCTS.ADD_DIALOG.SEARCH_PLACEHOLDER')"
        class="flex-1"
        @input="debouncedSearch"
      />
      <select
        v-if="itemGroups.length"
        v-model="selectedItemGroup"
        class="px-3 py-2 text-sm rounded-lg border bg-n-alpha-1 border-n-weak text-n-slate-12"
        @change="handleFilterChange"
      >
        <option value="">
          {{ $t('CAPTAIN_PRODUCTS.ADD_DIALOG.FILTER_ALL') }}
        </option>
        <option
          v-for="group in itemGroups"
          :key="group.name || group"
          :value="group.name || group"
        >
          {{ group.name || group }}
        </option>
      </select>
    </div>

    <!-- Select all + count bar -->
    <div
      v-if="searchResults.length > 0"
      class="flex items-center justify-between px-3 py-2 mb-2 rounded-lg bg-n-alpha-1"
    >
      <label class="flex items-center gap-2 cursor-pointer">
        <input
          type="checkbox"
          :checked="allSelectableChecked"
          :indeterminate="someSelectableChecked"
          class="w-4 h-4 rounded"
          @change="toggleSelectAll"
        />
        <!-- eslint-disable vue/no-bare-strings-in-template -->
        <span class="text-xs font-medium text-n-slate-11">
          Select all ({{ selectableItems.length }})
        </span>
        <!-- eslint-enable vue/no-bare-strings-in-template -->
      </label>
      <span class="text-xs text-n-slate-9">
        <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
        {{ searchResults.length }} of {{ totalItems }} loaded
      </span>
    </div>

    <!-- Results -->
    <div
      class="flex flex-col gap-2 min-h-[200px] max-h-[400px] overflow-y-auto"
    >
      <div
        v-if="isSearching"
        class="flex items-center justify-center h-[200px]"
      >
        <Spinner />
      </div>
      <div
        v-else-if="hasSearched && !searchResults.length"
        class="flex items-center justify-center h-[200px] text-sm text-n-slate-11"
      >
        {{ $t('CAPTAIN_PRODUCTS.ADD_DIALOG.NO_RESULTS') }}
      </div>
      <template v-else>
        <div
          v-for="item in searchResults"
          :key="item.item_code"
          class="flex items-center gap-3 p-3 rounded-lg border cursor-pointer transition-colors"
          :class="[
            isItemAdded(item.item_code)
              ? 'opacity-50 cursor-default border-n-weak'
              : selectedItems.has(item.item_code)
                ? 'border-b-500 bg-b-50 dark:bg-b-900/20'
                : 'border-n-weak hover:bg-n-alpha-1',
          ]"
          @click="toggleSelection(item.item_code)"
        >
          <input
            type="checkbox"
            :checked="selectedItems.has(item.item_code)"
            :disabled="isItemAdded(item.item_code)"
            class="w-4 h-4 rounded shrink-0"
            @click.stop="toggleSelection(item.item_code)"
          />
          <div class="flex flex-col flex-1 min-w-0">
            <span class="text-sm font-medium text-n-slate-12 line-clamp-1">
              {{ item.item_name }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{ item.item_code }}
              <span v-if="item.item_group"> · {{ item.item_group }}</span>
            </span>
          </div>
          <span
            v-if="item.price != null"
            class="text-sm font-medium text-n-slate-12 shrink-0"
          >
            {{ item.currency || '' }}
            {{
              Number(item.price).toLocaleString('en-US', {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2,
              })
            }}
          </span>
          <span
            v-if="isItemAdded(item.item_code)"
            class="inline-flex px-2 py-0.5 text-xs font-medium rounded bg-n-alpha-2 text-n-slate-11 shrink-0"
          >
            {{ $t('CAPTAIN_PRODUCTS.ADD_DIALOG.ALREADY_ADDED') }}
          </span>
        </div>

        <!-- Load more button -->
        <div v-if="hasMoreItems" class="flex justify-center py-3">
          <Button
            variant="faded"
            color="slate"
            size="small"
            :is-loading="isLoadingMore"
            @click="loadMore"
          >
            <!-- eslint-disable vue/no-bare-strings-in-template -->
            Load more ({{ searchResults.length }} / {{ totalItems }})
            <!-- eslint-enable vue/no-bare-strings-in-template -->
          </Button>
        </div>
      </template>
    </div>

    <!-- Footer -->
    <template #footer>
      <div class="flex items-center justify-between w-full pt-4">
        <span class="text-sm text-n-slate-11">
          {{
            $t('CAPTAIN_PRODUCTS.ADD_DIALOG.SELECTED_COUNT', {
              count: selectedCount,
            })
          }}
        </span>
        <div class="flex gap-3">
          <Button
            variant="faded"
            color="slate"
            :label="$t('DIALOG.BUTTONS.CANCEL')"
            @click="dialogRef.close()"
          />
          <Button
            :label="
              isAdding
                ? $t('CAPTAIN_PRODUCTS.ADD_DIALOG.ADDING')
                : $t('CAPTAIN_PRODUCTS.ADD_DIALOG.ADD_SELECTED')
            "
            :is-loading="isAdding"
            :disabled="selectedCount === 0 || isAdding"
            @click="handleAddSelected"
          />
        </div>
      </div>
    </template>
  </Dialog>
</template>
