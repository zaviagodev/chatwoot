<script setup>
import { ref, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import CaptainErpProxy from 'dashboard/api/captain/erpProxy';
import Icon from 'next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ProductCard from './ProductCard.vue';

const props = defineProps({
  assistantId: { type: Number, required: true },
  recentlyAdded: { type: Object, default: () => new Map() },
});

defineEmits(['addProduct']);

const { t } = useI18n();

const PAGE_SIZE = 20;

// State
const searchQuery = ref('');
const selectedCategory = ref('');
const products = ref([]);
const itemGroups = ref([]);
const page = ref(1);
const isLoading = ref(false);
const isLoadingMore = ref(false);
const hasMore = ref(false);
const error = ref(null);
const searchInputRef = ref(null);

// Focus search input (called by parent modal on open)
function focusSearch() {
  searchInputRef.value?.focus();
}

defineExpose({ focusSearch });

// Fetch products
async function fetchProducts({ append = false } = {}) {
  if (append) {
    isLoadingMore.value = true;
  } else {
    isLoading.value = true;
  }
  error.value = null;

  try {
    const { data } = await CaptainErpProxy.searchProducts({
      query: searchQuery.value,
      itemGroup: selectedCategory.value || undefined,
      page: page.value,
      assistantId: props.assistantId,
    });
    const items = data.products || data.data || data || [];
    const normalized = Array.isArray(items) ? items : [];

    if (append) {
      products.value = [...products.value, ...normalized];
    } else {
      products.value = normalized;
    }
    hasMore.value = normalized.length >= PAGE_SIZE;
  } catch (err) {
    error.value = err?.message || 'Unknown error';
    if (!append) {
      products.value = [];
    }
  } finally {
    isLoading.value = false;
    isLoadingMore.value = false;
  }
}

// Fetch item groups for category tabs
async function fetchItemGroups() {
  try {
    const { data } = await CaptainErpProxy.getItemGroups({
      assistantId: props.assistantId,
    });
    const groups = data.item_groups || data.data || data || [];
    itemGroups.value = Array.isArray(groups) ? groups : [];
  } catch {
    itemGroups.value = [];
  }
}

// Debounced search handler
const debouncedSearch = debounce(() => {
  page.value = 1;
  fetchProducts();
}, 300);

// Watch search query for debounced search
watch(searchQuery, () => {
  debouncedSearch();
});

// Watch category change for immediate reload
watch(selectedCategory, () => {
  page.value = 1;
  fetchProducts();
});

// Load more handler
function loadMore() {
  page.value += 1;
  fetchProducts({ append: true });
}

// Clear search
function clearSearch() {
  searchQuery.value = '';
  searchInputRef.value?.focus();
}

// Retry after error
function retry() {
  page.value = 1;
  fetchProducts();
}

// Select category
function selectCategory(groupName) {
  selectedCategory.value = groupName;
}

// Initial load
onMounted(() => {
  fetchProducts();
  fetchItemGroups();
});
</script>

<template>
  <div class="flex h-full flex-col overflow-hidden">
    <!-- Search bar -->
    <div class="relative px-4 pt-3">
      <div class="relative">
        <Icon
          icon="i-lucide-search"
          size="16"
          class="absolute left-3 top-1/2 -translate-y-1/2 text-n-slate-9"
        />
        <input
          ref="searchInputRef"
          v-model="searchQuery"
          type="text"
          class="w-full rounded-lg border border-n-weak bg-n-slate-2 py-2 pl-9 pr-9 text-sm text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-blue-9 focus:outline-none focus:ring-1 focus:ring-n-blue-9"
          :placeholder="
            t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.SEARCH_PLACEHOLDER')
          "
        />
        <button
          v-if="searchQuery"
          class="absolute right-3 top-1/2 -translate-y-1/2 text-n-slate-9 hover:text-n-slate-12"
          :aria-label="
            t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.SEARCH_CLEAR')
          "
          @click="clearSearch"
        >
          <Icon icon="i-lucide-x" size="14" />
        </button>
      </div>
    </div>

    <!-- Category tabs -->
    <div
      v-if="itemGroups.length > 0"
      class="flex gap-1 overflow-x-auto px-4 pt-3"
    >
      <button
        class="shrink-0 rounded-lg px-3 py-1.5 text-xs font-medium transition-colors"
        :class="
          selectedCategory === ''
            ? 'bg-n-blue-9 text-white'
            : 'bg-n-slate-3 text-n-slate-11 hover:bg-n-slate-4'
        "
        @click="selectCategory('')"
      >
        {{ t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.CATEGORY_ALL') }}
      </button>
      <button
        v-for="group in itemGroups"
        :key="group.name || group.value || group"
        class="shrink-0 rounded-lg px-3 py-1.5 text-xs font-medium transition-colors"
        :class="
          selectedCategory === (group.name || group.value || group)
            ? 'bg-n-blue-9 text-white'
            : 'bg-n-slate-3 text-n-slate-11 hover:bg-n-slate-4'
        "
        @click="selectCategory(group.name || group.value || group)"
      >
        {{ group.name || group.value || group }}
      </button>
    </div>

    <!-- Product grid area -->
    <div class="flex-1 overflow-y-auto px-4 py-3">
      <!-- Loading skeleton -->
      <div v-if="isLoading" class="grid grid-cols-2 gap-3 lg:grid-cols-3">
        <div
          v-for="n in 6"
          :key="n"
          class="flex flex-col overflow-hidden rounded-lg border border-n-weak bg-n-slate-2"
        >
          <div class="aspect-square w-full animate-pulse bg-n-slate-4" />
          <div class="flex flex-col gap-2 p-3">
            <div class="h-4 w-3/4 animate-pulse rounded bg-n-slate-4" />
            <div class="h-4 w-1/2 animate-pulse rounded bg-n-slate-4" />
            <div class="h-3 w-1/3 animate-pulse rounded bg-n-slate-4" />
          </div>
          <div class="px-3 pb-3">
            <div class="h-9 w-full animate-pulse rounded-lg bg-n-slate-4" />
          </div>
        </div>
      </div>

      <!-- Error state -->
      <div
        v-else-if="error"
        class="flex flex-col items-center justify-center gap-3 py-12"
      >
        <div
          class="rounded-lg border border-n-ruby-6 bg-n-ruby-3 px-4 py-3 text-center"
        >
          <p class="text-sm text-n-ruby-11">
            {{ t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.ERROR_LOADING') }}
          </p>
        </div>
        <Button
          :label="t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.RETRY')"
          variant="faded"
          color="slate"
          size="sm"
          @click="retry"
        />
      </div>

      <!-- Empty state -->
      <div
        v-else-if="products.length === 0 && !isLoading"
        class="flex flex-col items-center justify-center gap-2 py-12"
      >
        <Icon icon="i-lucide-search" size="32" class="text-n-slate-9" />
        <p class="text-sm text-n-slate-11">
          <template v-if="searchQuery">
            {{
              t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.NO_RESULTS', {
                query: searchQuery,
              })
            }}
          </template>
          <template v-else>
            {{ t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.NO_PRODUCTS') }}
          </template>
        </p>
        <p v-if="searchQuery" class="text-xs text-n-slate-9">
          {{ t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.NO_RESULTS_HINT') }}
        </p>
      </div>

      <!-- Product grid -->
      <div v-else>
        <div class="grid grid-cols-2 gap-3 lg:grid-cols-3">
          <ProductCard
            v-for="product in products"
            :key="product.item_code"
            :product="product"
            :just-added="recentlyAdded.has(product.item_code)"
            @add="$emit('addProduct', $event)"
          />
        </div>

        <!-- Load more -->
        <div v-if="hasMore" class="flex justify-center py-4">
          <Button
            :label="t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.LOAD_MORE')"
            variant="faded"
            color="slate"
            size="sm"
            :is-loading="isLoadingMore"
            @click="loadMore"
          />
        </div>
      </div>
    </div>
  </div>
</template>
