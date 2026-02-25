<script setup>
import { computed, onMounted, ref, nextTick } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { formatDistanceToNow, parseISO } from 'date-fns';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import ProductCard from 'dashboard/components-next/captain/assistant/ProductCard.vue';
import ProductPageEmptyState from 'dashboard/components-next/captain/pageComponents/emptyStates/ProductPageEmptyState.vue';
import AddProductsDialog from 'dashboard/components-next/captain/pageComponents/product/AddProductsDialog.vue';
import InlineDescriptionEditor from 'dashboard/components-next/captain/pageComponents/product/InlineDescriptionEditor.vue';
import AiEnrichPreview from 'dashboard/components-next/captain/pageComponents/product/AiEnrichPreview.vue';
import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';
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

// AI enrichment state
const enrichingProductId = ref(null);
const enrichedText = ref('');
const isEnriching = ref(false);
const enrichError = ref(false);

const fetchProducts = (page = 1) => {
  store.dispatch('captainProducts/get', {
    page,
    assistantId: selectedAssistantId.value,
  });
};

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

const handleAction = ({ action, id }) => {
  selectedProduct.value = products.value.find(p => p.id === id);

  nextTick(() => {
    if (action === 'delete') {
      handleDelete();
    } else if (action === 'viewDescription') {
      collapseEnrichPreview();
      expandedProductId.value = expandedProductId.value === id ? null : id;
      expandedMode.value = 'view';
    } else if (action === 'editDescription') {
      collapseEnrichPreview();
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
  expandedMode.value = 'view';
  fetchProducts();
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
    :button-label="$t('CAPTAIN_PRODUCTS.ADD_NEW')"
    :button-policy="['administrator']"
    :total-count="productsMeta.totalCount"
    :current-page="productsMeta.page"
    :show-pagination-footer="!isFetching && !!products.length"
    :is-fetching="isFetching"
    :is-empty="!products.length"
    :show-know-more="false"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
    @update:current-page="onPageChange"
    @click="handleOpenAddDialog"
  >
    <template #emptyState>
      <ProductPageEmptyState @click="handleOpenAddDialog" />
    </template>

    <template #paywall>
      <CaptainPaywall />
    </template>

    <template #body>
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

      <div class="flex flex-col gap-4">
        <template v-for="product in products" :key="product.id">
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
            @action="handleAction"
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
