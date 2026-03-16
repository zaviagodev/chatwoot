<script setup>
import { computed, onMounted, ref, nextTick, watch } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { formatDistanceToNow, parseISO } from 'date-fns';
import { debounce } from '@chatwoot/utils';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import ProductCard from 'dashboard/components-next/captain/assistant/ProductCard.vue';
import ProductPageEmptyState from 'dashboard/components-next/captain/pageComponents/emptyStates/ProductPageEmptyState.vue';
import ProductsToolbar from 'dashboard/components-next/captain/pageComponents/product/ProductsToolbar.vue';
import AddProductsDialog from 'dashboard/components-next/captain/pageComponents/product/AddProductsDialog.vue';
import InlineDescriptionEditor from 'dashboard/components-next/captain/pageComponents/product/InlineDescriptionEditor.vue';
import AiEnrichPreview from 'dashboard/components-next/captain/pageComponents/product/AiEnrichPreview.vue';
import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';
import VariantList from 'dashboard/components-next/captain/assistant/VariantList.vue';
import ProductFormDrawer from 'dashboard/components-next/captain/pageComponents/product/ProductFormDrawer.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const route = useRoute();
const store = useStore();
const { t } = useI18n();

const uiFlags = useMapGetter('captainProducts/getUIFlags');
const products = useMapGetter('captainProducts/getRecords');
const productsMeta = useMapGetter('captainProducts/getMeta');
const syncStatus = useMapGetter('captainProducts/getSyncStatus');

const isFetching = computed(() => uiFlags.value.fetchingList);
const selectedAssistantId = computed(() => Number(route.params.assistantId));
const isSyncing = computed(() => syncStatus.value?.isSyncing ?? false);
const syncErrorCount = computed(() => syncStatus.value?.syncErrorCount ?? 0);

const lastSyncedLabel = computed(() => {
  const ts = syncStatus.value?.lastSyncedAt;
  if (!ts) return null;
  try {
    return formatDistanceToNow(parseISO(ts), { addSuffix: true });
  } catch {
    return null;
  }
});

const showSyncErrorBanner = computed(() => syncErrorCount.value >= 3);

const selectedProduct = ref(null);
const expandedProductId = ref(null);
const expandedMode = ref('view');
const showAddDialog = ref(false);
const addProductsDialog = ref(null);
const deleteProductDialog = ref(null);

// Product form drawer state
const showProductDrawer = ref(false);
const editingProduct = ref(null);

const existingCategories = computed(() => {
  const cats = products.value.map(p => p.item_group).filter(Boolean);
  return [...new Set(cats)];
});

// Search & filter state
const searchQuery = ref('');
const debouncedSearch = ref('');
const filterValue = ref('all');

const applyDebouncedSearch = debounce(val => {
  debouncedSearch.value = val;
}, 300);

watch(searchQuery, val => applyDebouncedSearch(val));

const filteredProducts = computed(() => {
  let result = products.value;
  const q = debouncedSearch.value.toLowerCase().trim();
  if (q) {
    result = result.filter(
      p =>
        (p.item_name || '').toLowerCase().includes(q) ||
        (p.item_code || '').toLowerCase().includes(q) ||
        (p.item_group || '').toLowerCase().includes(q)
    );
  }
  if (filterValue.value === 'in_stock') {
    result = result.filter(p => p.stock_status === 'in_stock');
  } else if (filterValue.value === 'out_of_stock') {
    result = result.filter(p => p.stock_status === 'out_of_stock');
  } else if (filterValue.value === 'erp') {
    result = result.filter(p => !!p.erp_company);
  } else if (filterValue.value === 'manual') {
    result = result.filter(p => !p.erp_company);
  }
  return result;
});

const handleAddManually = () => {
  editingProduct.value = null;
  showProductDrawer.value = true;
};

const handleOpenEditDrawer = id => {
  editingProduct.value = products.value.find(p => p.id === id) || null;
  showProductDrawer.value = true;
};

const fetchProducts = (page = 1) => {
  store.dispatch('captainProducts/get', {
    page,
    assistantId: selectedAssistantId.value,
  });
};

const handleDrawerClose = () => {
  showProductDrawer.value = false;
  editingProduct.value = null;
};

const handleDrawerSaved = () => {
  showProductDrawer.value = false;
  editingProduct.value = null;
  fetchProducts();
};

// AI enrichment state
const enrichingProductId = ref(null);
const enrichedText = ref('');
const isEnriching = ref(false);
const enrichError = ref(false);

const fetchSyncStatus = () => {
  store.dispatch('captainProducts/fetchSyncStatus', {
    assistantId: selectedAssistantId.value,
  });
};

const onPageChange = page => fetchProducts(page);

const handleOpenAddDialog = () => {
  showAddDialog.value = true;
  nextTick(() => addProductsDialog.value?.dialogRef?.open());
};

const handleAddDialogClose = () => {
  showAddDialog.value = false;
  fetchProducts();
};

const handleDelete = () => {
  deleteProductDialog.value?.dialogRef?.open();
};

const handleSyncNow = async () => {
  try {
    const result = await store.dispatch('captainProducts/syncProducts', {
      assistantId: selectedAssistantId.value,
    });
    if (result?.synced_count != null) {
      useAlert(
        t('CAPTAIN_PRODUCTS.TOAST.SYNC_SUCCESS', {
          count: result.synced_count,
        })
      );
      fetchProducts();
    }
  } catch {
    useAlert(t('CAPTAIN_PRODUCTS.TOAST.SYNC_ERROR'));
  }
};

const collapseEnrichPreview = () => {
  enrichingProductId.value = null;
  enrichedText.value = '';
  enrichError.value = false;
  isEnriching.value = false;
};

const handleResync = async id => {
  const product = products.value.find(p => p.id === id);
  if (!product) return;

  if (product.description_source !== 'auto') {
    // eslint-disable-next-line no-alert
    if (!window.confirm(t('CAPTAIN_PRODUCTS.RESYNC_CONFIRM'))) {
      return;
    }
  }

  try {
    await store.dispatch('captainProducts/update', {
      assistantId: selectedAssistantId.value,
      id,
      reset_source: 'true',
    });
    useAlert(t('CAPTAIN_PRODUCTS.TOAST.RESYNCED'));
  } catch {
    useAlert(t('CAPTAIN_PRODUCTS.TOAST.SYNC_ERROR'));
  }
};

const handleAiEnrich = async id => {
  expandedProductId.value = null;
  enrichingProductId.value = id;
  enrichedText.value = '';
  enrichError.value = false;
  isEnriching.value = true;

  try {
    const result = await store.dispatch('captainProducts/enrichProduct', {
      assistantId: selectedAssistantId.value,
      id,
    });
    if (result?.enriched_text) {
      enrichedText.value = result.enriched_text;
    } else {
      enrichError.value = true;
    }
  } catch {
    enrichError.value = true;
  } finally {
    isEnriching.value = false;
  }
};

const cardExpandedId = ref(null);

const handleCardExpand = id => {
  collapseEnrichPreview();
  handleOpenEditDrawer(id);
};

const handleAction = ({ action, id }) => {
  selectedProduct.value = products.value.find(p => p.id === id);

  nextTick(() => {
    if (action === 'delete') {
      handleDelete();
    } else if (action === 'viewDescription') {
      collapseEnrichPreview();
      cardExpandedId.value = id;
      expandedProductId.value = expandedProductId.value === id ? null : id;
      expandedMode.value = 'view';
    } else if (action === 'editDescription') {
      collapseEnrichPreview();
      cardExpandedId.value = id;
      expandedProductId.value = id;
      expandedMode.value = 'edit';
    } else if (action === 'resync') {
      handleResync(id);
    } else if (action === 'aiEnrich') {
      handleAiEnrich(id);
    }
  });
};

const handleEnrichApprove = async text => {
  const id = enrichingProductId.value;
  try {
    await store.dispatch('captainProducts/approveEnrichment', {
      assistantId: selectedAssistantId.value,
      id,
      text,
    });
    useAlert(t('CAPTAIN_PRODUCTS.TOAST.ENRICHED'));
    collapseEnrichPreview();
    fetchProducts();
  } catch {
    useAlert(t('CAPTAIN_PRODUCTS.TOAST.ENRICH_ERROR'));
  }
};

const handleEnrichEdit = () => {
  const productId = enrichingProductId.value;
  collapseEnrichPreview();
  if (productId) {
    expandedProductId.value = productId;
    expandedMode.value = 'edit';
  }
};

const handleDescriptionSaved = () => {
  expandedProductId.value = null;
  cardExpandedId.value = null;
  expandedMode.value = 'view';
  fetchProducts();
};

const handleVariantToggle = async (productId, itemCode) => {
  const product = products.value.find(p => p.id === productId);
  if (!product?.variants) return;

  const updatedVariants = product.variants.map(v =>
    v.item_code === itemCode ? { ...v, enabled: v.enabled === false } : v
  );

  try {
    await store.dispatch('captainProducts/update', {
      assistantId: selectedAssistantId.value,
      id: productId,
      variants: updatedVariants,
    });
  } catch {
    useAlert(t('CAPTAIN_PRODUCTS.TOAST.SYNC_ERROR'));
  }
};

const handleBulkToggle = async (productId, enableAll) => {
  const product = products.value.find(p => p.id === productId);
  if (!product?.variants) return;

  const updatedVariants = product.variants.map(v => ({
    ...v,
    enabled: enableAll,
  }));

  try {
    await store.dispatch('captainProducts/update', {
      assistantId: selectedAssistantId.value,
      id: productId,
      variants: updatedVariants,
    });
  } catch {
    useAlert(t('CAPTAIN_PRODUCTS.TOAST.SYNC_ERROR'));
  }
};

const onDeleteSuccess = () => {
  selectedProduct.value = null;
  if (products.value?.length === 0 && productsMeta.value?.page > 1) {
    onPageChange(productsMeta.value.page - 1);
  }
};

onMounted(() => {
  fetchProducts();
  fetchSyncStatus();
});
</script>

<template>
  <PageLayout
    :header-title="$t('CAPTAIN_PRODUCTS.HEADER')"
    button-label=""
    :button-policy="['administrator']"
    :total-count="productsMeta.totalCount"
    :current-page="productsMeta.page"
    :show-pagination-footer="!isFetching && !!products.length"
    :is-fetching="false"
    :is-empty="!products.length && !isFetching"
    :show-know-more="false"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
    @update:current-page="onPageChange"
  >
    <template #emptyState>
      <ProductPageEmptyState
        @add-from-erp="handleOpenAddDialog"
        @add-manually="handleAddManually"
      />
    </template>

    <template #paywall>
      <CaptainPaywall />
    </template>

    <template #body>
      <!-- Toolbar -->
      <ProductsToolbar
        :total-count="products.length"
        :search-query="searchQuery"
        :filter-value="filterValue"
        @update:search-query="searchQuery = $event"
        @update:filter-value="filterValue = $event"
        @add-from-erp="handleOpenAddDialog"
        @add-manually="handleAddManually"
      />

      <!-- Sync status bar -->
      <div
        v-if="products.length"
        class="flex items-center justify-between mb-4"
      >
        <span class="text-xs text-n-slate-10">
          <template v-if="isSyncing">
            {{ $t('CAPTAIN_PRODUCTS.SYNC.SYNCING') }}
          </template>
          <template v-else-if="lastSyncedLabel">
            {{
              $t('CAPTAIN_PRODUCTS.SYNC.LAST_SYNCED', { time: lastSyncedLabel })
            }}
          </template>
        </span>
        <Button
          icon="i-lucide-refresh-cw"
          color="slate"
          size="xs"
          :class="{ 'animate-spin': isSyncing }"
          :disabled="isSyncing"
          :title="$t('CAPTAIN_PRODUCTS.SYNC.SYNC_NOW')"
          @click="handleSyncNow"
        />
      </div>

      <!-- Sync error banner -->
      <div
        v-if="showSyncErrorBanner"
        class="flex items-center gap-2 p-3 mb-4 text-sm rounded-lg bg-y-50 text-y-800 dark:bg-y-900/20 dark:text-y-300"
      >
        <span class="i-lucide-alert-triangle w-4 h-4 shrink-0" />
        {{ $t('CAPTAIN_PRODUCTS.SYNC.ERROR_BANNER') }}
        <button
          class="ml-auto text-xs font-medium underline"
          @click="handleSyncNow"
        >
          {{ $t('CAPTAIN_PRODUCTS.SYNC.RETRY') }}
        </button>
      </div>

      <!-- Loading skeletons -->
      <div v-if="isFetching" class="flex flex-col gap-4">
        <div
          v-for="n in 4"
          :key="n"
          class="h-20 rounded-xl bg-n-alpha-2 animate-pulse"
        />
      </div>

      <!-- No results after search/filter -->
      <div
        v-else-if="filteredProducts.length === 0 && products.length > 0"
        class="flex flex-col items-center gap-2 py-12 text-center"
      >
        <p class="text-sm text-n-slate-11">
          {{ $t('CAPTAIN_PRODUCTS.SEARCH.NO_RESULTS_TITLE') }}
        </p>
        <button
          class="text-xs text-b-600 hover:text-b-700 font-medium"
          @click="
            searchQuery = '';
            filterValue = 'all';
          "
        >
          {{ $t('CAPTAIN_PRODUCTS.SEARCH.CLEAR_SEARCH') }}
        </button>
      </div>

      <!-- Product list (table mode) -->
      <div v-else class="flex flex-col gap-4">
        <template v-for="product in filteredProducts" :key="product.id">
          <ProductCard
            :id="product.id"
            :item-name="product.item_name"
            :item-code="product.item_code"
            :price="product.price"
            :currency="product.currency"
            :stock-qty="product.stock_qty"
            :stock-status="product.stock_status"
            :description-source="product.description_source"
            :item-group="product.item_group"
            :variants="product.variants || []"
            :has-variants="!!(product.variants && product.variants.length)"
            :is-expanded="cardExpandedId === product.id"
            :image-url="product.image_url"
            :erp-company="product.erp_company"
            @action="handleAction"
            @expand="handleCardExpand"
          />
          <InlineDescriptionEditor
            v-if="expandedProductId === product.id"
            :product="product"
            :mode="expandedMode"
            :assistant-id="selectedAssistantId"
            @saved="handleDescriptionSaved"
            @close="expandedProductId = null"
            @edit="expandedMode = 'edit'"
          />
          <VariantList
            v-if="
              cardExpandedId === product.id &&
              product.variants &&
              product.variants.length
            "
            :variants="product.variants"
            :currency="product.currency"
            :parent-price="product.price"
            @toggle="itemCode => handleVariantToggle(product.id, itemCode)"
            @bulk-toggle="enableAll => handleBulkToggle(product.id, enableAll)"
          />
          <AiEnrichPreview
            v-if="enrichingProductId === product.id"
            :product="product"
            :enriched-text="enrichedText"
            :is-loading="isEnriching"
            :has-error="enrichError"
            @approve="handleEnrichApprove"
            @edit="handleEnrichEdit"
            @discard="collapseEnrichPreview"
            @retry="handleAiEnrich(product.id)"
          />
        </template>
      </div>
    </template>

    <AddProductsDialog
      v-if="showAddDialog"
      ref="addProductsDialog"
      :assistant-id="selectedAssistantId"
      :existing-products="products"
      @close="handleAddDialogClose"
    />
    <ProductFormDrawer
      :is-open="showProductDrawer"
      :product="editingProduct"
      :assistant-id="selectedAssistantId"
      :existing-categories="existingCategories"
      @close="handleDrawerClose"
      @saved="handleDrawerSaved"
    />
    <DeleteDialog
      v-if="selectedProduct"
      ref="deleteProductDialog"
      :entity="selectedProduct"
      type="Products"
      translation-key="PRODUCTS"
      :delete-payload="{
        id: selectedProduct.id,
        assistantId: selectedAssistantId,
      }"
      @delete-success="onDeleteSuccess"
    />
  </PageLayout>
</template>
