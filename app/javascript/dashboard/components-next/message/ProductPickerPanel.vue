<script setup>
import { ref, computed, watch, onMounted, onUnmounted, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import CaptainErpProxy from 'dashboard/api/captain/erpProxy';
import Icon from 'next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
  erpTenantKey: {
    type: String,
    default: '',
  },
  isSending: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close', 'send']);

const { t } = useI18n();

// State
const view = ref('search'); // 'search' | 'preview'
const searchQuery = ref('');
const searchResults = ref([]);
const isSearching = ref(false);
const hasError = ref(false);
const selectedProduct = ref(null);
const searchInputRef = ref(null);
const sendButtonRef = ref(null);
const focusedIndex = ref(-1);
const liveMessage = ref('');
const productRefs = ref([]);

// Reset focused index when results change and announce count
watch(searchResults, newResults => {
  focusedIndex.value = -1;
  if (!hasError.value && !isSearching.value) {
    liveMessage.value = `${newResults.length} products found`;
  }
});

// Storefront URL construction
const buildStorefrontUrl = itemCode => {
  if (!props.erpTenantKey || !itemCode) return '';
  return `https://${props.erpTenantKey}.shop.zaviago.com/product/${itemCode}`;
};

// Format price
const formattedPrice = computed(() => {
  if (!selectedProduct.value) return '';
  const { price, currency } = selectedProduct.value;
  if (!price && price !== 0) return '';
  const curr = currency || 'THB';
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: curr,
      minimumFractionDigits: 0,
      maximumFractionDigits: 2,
    }).format(price);
  } catch {
    return `${curr} ${price}`;
  }
});

// Format price for list item
const formatListPrice = product => {
  const { price, currency } = product;
  if (!price && price !== 0) return '';
  const curr = currency || 'THB';
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: curr,
      minimumFractionDigits: 0,
      maximumFractionDigits: 2,
    }).format(price);
  } catch {
    return `${curr} ${price}`;
  }
};

// Search products
const searchProducts = async () => {
  isSearching.value = true;
  hasError.value = false;
  try {
    const { data } = await CaptainErpProxy.searchProducts({
      query: searchQuery.value,
      assistantId: props.assistantId,
      page: 1,
    });
    const items = data.products || data.data || data || [];
    searchResults.value = Array.isArray(items) ? items : [];
  } catch {
    hasError.value = true;
    searchResults.value = [];
  } finally {
    isSearching.value = false;
  }
};

const debouncedSearch = debounce(() => {
  searchProducts();
}, 300);

const onSearchInput = () => {
  debouncedSearch();
};

// Empty state text
const emptyStateText = computed(() => {
  if (searchQuery.value) {
    return t('CONVERSATION.REPLYBOX.PRODUCT_PICKER.NO_RESULTS_QUERY', {
      query: searchQuery.value,
    });
  }
  return t('CONVERSATION.REPLYBOX.PRODUCT_PICKER.NO_RESULTS');
});

// Select a product
const selectProduct = product => {
  selectedProduct.value = product;
  view.value = 'preview';
  liveMessage.value = `${product.item_name} selected. Preview shown.`;
  nextTick(() => {
    sendButtonRef.value?.$el?.focus();
  });
};

// Go back to search
const goBack = () => {
  view.value = 'search';
  nextTick(() => {
    searchInputRef.value?.focus();
  });
};

// Send product card
const sendProduct = () => {
  if (!selectedProduct.value || props.isSending) return;

  const product = selectedProduct.value;
  const productPayload = {
    item_code: product.item_code,
    item_name: product.item_name,
    price: product.price,
    currency: product.currency || 'THB',
    image_url: product.image_url || product.image || null,
    storefront_url: buildStorefrontUrl(product.item_code),
    stock_status: product.stock_status || 'unknown',
  };

  emit('send', productPayload);
};

// Keyboard handling: Escape, ArrowDown/Up, Enter
const handleKeydown = event => {
  if (event.key === 'Escape') {
    event.stopPropagation();
    if (view.value === 'preview') {
      goBack();
    } else {
      emit('close');
    }
    return;
  }

  // Arrow key navigation only in search view with results
  if (view.value !== 'search' || searchResults.value.length === 0) return;

  if (event.key === 'ArrowDown') {
    event.preventDefault();
    focusedIndex.value =
      focusedIndex.value < searchResults.value.length - 1
        ? focusedIndex.value + 1
        : 0;
    productRefs.value[focusedIndex.value]?.scrollIntoView({ block: 'nearest' });
  } else if (event.key === 'ArrowUp') {
    event.preventDefault();
    focusedIndex.value =
      focusedIndex.value > 0
        ? focusedIndex.value - 1
        : searchResults.value.length - 1;
    productRefs.value[focusedIndex.value]?.scrollIntoView({ block: 'nearest' });
  } else if (event.key === 'Enter' && focusedIndex.value >= 0) {
    event.preventDefault();
    selectProduct(searchResults.value[focusedIndex.value]);
  }
};

onMounted(() => {
  document.addEventListener('keydown', handleKeydown);
  searchProducts(); // Initial browse-all
  nextTick(() => {
    searchInputRef.value?.focus();
  });
});

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeydown);
});
</script>

<template>
  <div
    class="flex flex-col bg-white dark:bg-n-slate-2 border-t border-n-slate-6 h-80"
  >
    <!-- Search View -->
    <template v-if="view === 'search'">
      <!-- Header -->
      <div
        class="flex items-center justify-between px-3 py-2 border-b border-n-slate-6"
      >
        <span class="text-sm font-semibold text-n-slate-12">
          {{ $t('CONVERSATION.REPLYBOX.PRODUCT_PICKER.TITLE') }}
        </span>
        <button
          :aria-label="$t('CONVERSATION.REPLYBOX.PRODUCT_PICKER.CLOSE_ARIA')"
          class="p-1 rounded hover:bg-n-slate-3 text-n-slate-11"
          @click="$emit('close')"
        >
          <Icon icon="i-lucide-x" size="16" />
        </button>
      </div>

      <!-- Search Input -->
      <div class="px-3 py-2">
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
            :placeholder="
              $t('CONVERSATION.REPLYBOX.PRODUCT_PICKER.SEARCH_PLACEHOLDER')
            "
            :aria-label="$t('CONVERSATION.REPLYBOX.PRODUCT_PICKER.SEARCH_ARIA')"
            class="w-full h-9 pl-10 pr-8 text-sm border border-n-slate-6 rounded-lg bg-white dark:bg-n-slate-3 text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:ring-2 focus:ring-n-blue-9 focus:border-transparent"
            @input="onSearchInput"
          />
          <button
            v-if="searchQuery"
            class="absolute right-2.5 top-1/2 -translate-y-1/2 text-n-slate-9 hover:text-n-slate-11"
            @click="
              searchQuery = '';
              searchProducts();
            "
          >
            <Icon icon="i-lucide-x" size="14" />
          </button>
          <Spinner
            v-if="isSearching"
            class="absolute right-2.5 top-1/2 -translate-y-1/2"
            size="small"
          />
        </div>
      </div>

      <!-- Results -->
      <div class="flex-1 overflow-y-auto px-1">
        <!-- Error state -->
        <div
          v-if="hasError"
          class="flex flex-col items-center justify-center h-full px-4 text-center"
        >
          <p class="text-sm text-n-ruby-11 mb-2">
            {{ $t('CONVERSATION.REPLYBOX.PRODUCT_PICKER.ERROR_MESSAGE') }}
          </p>
          <button
            class="text-sm text-n-blue-11 hover:underline"
            @click="searchProducts"
          >
            {{ $t('CONVERSATION.REPLYBOX.PRODUCT_PICKER.RETRY') }}
          </button>
        </div>

        <!-- Empty state -->
        <div
          v-else-if="!isSearching && searchResults.length === 0"
          class="flex flex-col items-center justify-center h-full text-center px-4"
        >
          <Icon icon="i-lucide-search" size="24" class="text-n-slate-9 mb-2" />
          <p class="text-sm text-n-slate-11">
            {{ emptyStateText }}
          </p>
        </div>

        <!-- Product list -->
        <div
          v-else
          role="listbox"
          :aria-label="$t('CONVERSATION.REPLYBOX.PRODUCT_PICKER.RESULTS_ARIA')"
        >
          <button
            v-for="(product, index) in searchResults"
            :ref="
              el => {
                if (el) productRefs[index] = el;
              }
            "
            :key="product.item_code"
            role="option"
            :aria-selected="index === focusedIndex"
            tabindex="-1"
            class="flex items-center w-full px-2 py-2 rounded-lg hover:bg-n-slate-3 cursor-pointer text-left transition-colors"
            :class="{
              'bg-n-slate-3 ring-2 ring-n-blue-9': index === focusedIndex,
            }"
            @click="selectProduct(product)"
          >
            <!-- Thumbnail -->
            <div
              class="flex-shrink-0 w-10 h-10 rounded bg-n-slate-3 overflow-hidden mr-3"
            >
              <img
                v-if="product.image_url"
                :src="product.image_url"
                :alt="product.item_name"
                class="w-full h-full object-cover"
              />
              <div
                v-else
                class="w-full h-full flex items-center justify-center"
              >
                <Icon
                  icon="i-lucide-package"
                  size="16"
                  class="text-n-slate-9"
                />
              </div>
            </div>

            <!-- Name -->
            <div class="flex-1 min-w-0 mr-2">
              <p class="text-sm text-n-slate-12 truncate leading-tight">
                {{ product.item_name }}
              </p>
            </div>

            <!-- Price + stock -->
            <div class="flex items-center gap-1.5 flex-shrink-0">
              <span class="text-sm text-n-slate-11">
                {{ formatListPrice(product) }}
              </span>
              <span
                class="w-2 h-2 rounded-full flex-shrink-0"
                :class="{
                  'bg-n-green-9': product.stock_status === 'in_stock',
                  'bg-n-ruby-9': product.stock_status === 'out_of_stock',
                  'bg-n-slate-8':
                    !product.stock_status || product.stock_status === 'unknown',
                }"
              />
            </div>
          </button>
        </div>
      </div>
    </template>

    <!-- Preview View -->
    <template v-else-if="view === 'preview' && selectedProduct">
      <div class="flex flex-col h-full">
        <!-- Preview content -->
        <div class="flex-1 overflow-y-auto p-3">
          <!-- Product image -->
          <div
            v-if="selectedProduct.image_url"
            class="w-full aspect-video rounded-lg overflow-hidden bg-n-slate-3 mb-3"
          >
            <img
              :src="selectedProduct.image_url"
              :alt="selectedProduct.item_name"
              class="w-full h-full object-cover"
            />
          </div>
          <div
            v-else
            class="w-full aspect-video rounded-lg bg-n-slate-3 mb-3 flex flex-col items-center justify-center"
          >
            <Icon
              icon="i-lucide-package"
              size="32"
              class="text-n-slate-9 mb-1"
            />
            <span class="text-xs text-n-slate-9">
              {{ $t('CONVERSATION.REPLYBOX.PRODUCT_PICKER.NO_IMAGE') }}
            </span>
          </div>

          <!-- Product info -->
          <p class="text-base font-semibold text-n-slate-12 mb-1">
            {{ selectedProduct.item_name }}
          </p>
          <p v-if="formattedPrice" class="text-sm text-n-slate-11 mb-2">
            {{ formattedPrice }}
          </p>
          <p
            v-if="buildStorefrontUrl(selectedProduct.item_code)"
            class="text-xs text-n-slate-9 truncate"
          >
            {{ buildStorefrontUrl(selectedProduct.item_code) }}
          </p>
        </div>

        <!-- Actions -->
        <div
          class="flex items-center justify-between px-3 py-2 border-t border-n-slate-6"
        >
          <button
            class="text-sm text-n-slate-11 hover:text-n-slate-12"
            @click="goBack"
          >
            {{ $t('CONVERSATION.REPLYBOX.PRODUCT_PICKER.BACK') }}
          </button>
          <Button
            ref="sendButtonRef"
            sm
            solid
            blue
            :is-loading="props.isSending"
            :disabled="props.isSending"
            @click="sendProduct"
          >
            {{ $t('CONVERSATION.REPLYBOX.PRODUCT_PICKER.SEND') }}
          </Button>
        </div>
      </div>
    </template>
    <!-- Screen reader announcements -->
    <div aria-live="polite" class="sr-only">
      {{ liveMessage }}
    </div>
  </div>
</template>
