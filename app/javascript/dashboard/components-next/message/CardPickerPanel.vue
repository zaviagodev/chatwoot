<script setup>
import { ref, computed, watch, onMounted, onUnmounted, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { debounce } from '@chatwoot/utils';
import CaptainErpProxy from 'dashboard/api/captain/erpProxy';
import Icon from 'next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import LineFlexPreview from 'dashboard/components-next/card-design/LineFlexPreview.vue';

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
const MAX_CAROUSEL_ITEMS = 12;
const MIN_CAROUSEL_ITEMS = 2;

const { t } = useI18n();
const store = useStore();

// --- Card Designs ---
const designs = computed(() => store.getters.getCardDesigns);
const designUiFlags = computed(() => store.getters.getCardDesignUIFlags);
const selectedDesign = ref(null);

// Pre-select default design when designs load
watch(
  designs,
  newDesigns => {
    if (newDesigns.length && !selectedDesign.value) {
      selectedDesign.value =
        newDesigns.find(d => d.is_default) || newDesigns[0];
    }
  },
  { immediate: true }
);

const selectDesign = design => {
  selectedDesign.value = design;
};

// --- State (declared before watchers that reference them) ---
const selectedProduct = ref(null);
const liveMessage = ref('');

// --- Carousel Mode ---
const carouselMode = ref(false);
const selectedProducts = ref([]);

const isAtLimit = computed(
  () => selectedProducts.value.length >= MAX_CAROUSEL_ITEMS
);
const canSendCarousel = computed(
  () => selectedProducts.value.length >= MIN_CAROUSEL_ITEMS
);

watch(carouselMode, newVal => {
  if (newVal) {
    selectedProduct.value = null;
  } else {
    selectedProducts.value = [];
  }
});

const isProductSelected = product => {
  return selectedProducts.value.some(p => p.item_code === product.item_code);
};

const getProductSelectionIndex = product => {
  return selectedProducts.value.findIndex(
    p => p.item_code === product.item_code
  );
};

const toggleProductSelection = product => {
  const idx = getProductSelectionIndex(product);
  if (idx >= 0) {
    selectedProducts.value.splice(idx, 1);
    liveMessage.value = `${product.item_name} removed. ${selectedProducts.value.length} selected.`;
  } else if (!isAtLimit.value) {
    selectedProducts.value.push(product);
    liveMessage.value = `${product.item_name} added. ${selectedProducts.value.length} selected.`;
  }
};

// --- Product Search ---
const searchQuery = ref('');
const searchResults = ref([]);
const isSearching = ref(false);
const hasError = ref(false);
const searchInputRef = ref(null);
const sendButtonRef = ref(null);
const focusedIndex = ref(-1);
const productRefs = ref([]);
const designStripRef = ref(null);

watch(searchResults, newResults => {
  focusedIndex.value = -1;
  if (!hasError.value && !isSearching.value) {
    liveMessage.value = `${newResults.length} products found`;
  }
});

const buildStorefrontUrl = itemCode => {
  if (!props.erpTenantKey || !itemCode) return '';
  return `https://${props.erpTenantKey}.shop.zaviago.com/product/${itemCode}`;
};

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

const emptyStateText = computed(() => {
  if (searchQuery.value) {
    return t('CONVERSATION.REPLYBOX.CARD_PICKER.NO_RESULTS_QUERY', {
      query: searchQuery.value,
    });
  }
  return t('CONVERSATION.REPLYBOX.CARD_PICKER.NO_RESULTS');
});

// --- Single Product Selection & Preview ---
const selectProduct = product => {
  selectedProduct.value = product;
  liveMessage.value = `${product.item_name} selected. Preview shown.`;
  nextTick(() => {
    sendButtonRef.value?.$el?.focus();
  });
};

const goBack = () => {
  selectedProduct.value = null;
  nextTick(() => {
    searchInputRef.value?.focus();
  });
};

const contentData = computed(() => {
  if (!selectedProduct.value) return null;
  const p = selectedProduct.value;
  return {
    item_name: p.item_name,
    price: p.price,
    currency: p.currency || 'THB',
    image_url: p.image_url || null,
    subtitle: null,
  };
});

const makeProductPayload = product => ({
  item_code: product.item_code,
  item_name: product.item_name,
  price: product.price,
  currency: product.currency || 'THB',
  image_url: product.image_url || null,
  storefront_url: buildStorefrontUrl(product.item_code),
  stock_status: product.stock_status || 'unknown',
});

const carouselContentDataList = computed(() =>
  selectedProducts.value.map(p => ({
    item_name: p.item_name,
    price: p.price,
    currency: p.currency || 'THB',
    image_url: p.image_url || null,
    subtitle: null,
  }))
);

// --- Send ---
const sendCard = () => {
  if (!selectedProduct.value || !selectedDesign.value || props.isSending)
    return;

  emit('send', {
    product: makeProductPayload(selectedProduct.value),
    design_id: selectedDesign.value.id,
  });
};

const sendCarousel = () => {
  if (!canSendCarousel.value || !selectedDesign.value || props.isSending)
    return;

  emit('send', {
    products: selectedProducts.value.map(makeProductPayload),
    design_id: selectedDesign.value.id,
  });
};

// --- Product Click Handler ---
const handleProductClick = product => {
  if (carouselMode.value) {
    toggleProductSelection(product);
  } else {
    selectProduct(product);
  }
};

// --- Keyboard Navigation ---
const handleKeydown = event => {
  if (event.key === 'Escape') {
    event.stopPropagation();
    if (selectedProduct.value) {
      goBack();
    } else {
      emit('close');
    }
    return;
  }

  // In single-card preview mode, no arrow/enter nav
  if (selectedProduct.value || searchResults.value.length === 0) return;

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
    handleProductClick(searchResults.value[focusedIndex.value]);
  }
};

// --- Show search zone ---
const showSearchZone = computed(() => {
  if (carouselMode.value) return true;
  return !selectedProduct.value;
});

onMounted(() => {
  document.addEventListener('keydown', handleKeydown);
  if (!designs.value.length) {
    store.dispatch('getCardDesigns');
  }
  searchProducts();
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
    class="flex flex-col bg-white dark:bg-n-slate-2 border-t border-n-slate-6"
    :class="carouselMode && selectedProducts.length > 0 ? 'h-[420px]' : 'h-80'"
  >
    <!-- Zone 1: Header + Design Strip -->
    <div class="flex-shrink-0 border-b border-n-slate-6">
      <!-- Header -->
      <div class="flex items-center justify-between px-3 py-2">
        <span class="text-sm font-semibold text-n-slate-12">
          {{ $t('CONVERSATION.REPLYBOX.CARD_PICKER.TITLE') }}
        </span>
        <div class="flex items-center gap-2">
          <!-- Carousel toggle -->
          <label class="flex items-center gap-1.5 cursor-pointer">
            <span class="text-xs text-n-slate-11">
              {{ $t('CONVERSATION.REPLYBOX.CARD_PICKER.CAROUSEL_TOGGLE') }}
            </span>
            <ToggleSwitch v-model="carouselMode" />
          </label>
          <button
            :aria-label="$t('CONVERSATION.REPLYBOX.CARD_PICKER.CLOSE_ARIA')"
            class="p-1 rounded hover:bg-n-slate-3 text-n-slate-11"
            @click="$emit('close')"
          >
            <Icon icon="i-lucide-x" size="16" />
          </button>
        </div>
      </div>

      <!-- Design Strip -->
      <div
        v-if="designUiFlags.fetchingList"
        class="flex items-center justify-center px-3 pb-2 h-[76px]"
      >
        <Spinner size="small" />
        <span class="ml-2 text-xs text-n-slate-9">
          {{ $t('CONVERSATION.REPLYBOX.CARD_PICKER.LOADING_DESIGNS') }}
        </span>
      </div>
      <div
        v-else-if="designs.length === 0"
        class="flex items-center justify-center px-3 pb-2 h-[76px]"
      >
        <span class="text-xs text-n-slate-9">
          {{ $t('CONVERSATION.REPLYBOX.CARD_PICKER.NO_DESIGNS') }}
        </span>
      </div>
      <div
        v-else
        ref="designStripRef"
        class="flex gap-2 px-3 pb-2 overflow-x-auto scroll-smooth"
        role="radiogroup"
        :aria-label="$t('CONVERSATION.REPLYBOX.CARD_PICKER.DESIGN_STRIP_ARIA')"
      >
        <button
          v-for="design in designs"
          :key="design.id"
          role="radio"
          :aria-checked="selectedDesign?.id === design.id"
          :aria-label="
            $t('CONVERSATION.REPLYBOX.CARD_PICKER.DESIGN_ARIA', {
              name: design.name,
            })
          "
          class="flex-shrink-0 w-14 h-[72px] rounded-md border-2 overflow-hidden cursor-pointer transition-all"
          :class="
            selectedDesign?.id === design.id
              ? 'border-n-blue-9 bg-n-blue-3'
              : 'border-transparent hover:border-n-slate-8'
          "
          @click="selectDesign(design)"
        >
          <LineFlexPreview :design-json="design.design_json" :scale="0.2" />
        </button>
      </div>
    </div>

    <!-- Carousel selection counter -->
    <div
      v-if="carouselMode && selectedProducts.length > 0"
      class="flex-shrink-0 px-3 py-1.5 bg-n-blue-3 dark:bg-n-blue-3/20"
      aria-live="polite"
    >
      <span class="text-xs font-medium text-n-blue-11">
        {{
          $t('CONVERSATION.REPLYBOX.CARD_PICKER.CAROUSEL_COUNTER', {
            count: selectedProducts.length,
          })
        }}
      </span>
    </div>

    <!-- Zone 2: Product Search -->
    <template v-if="showSearchZone">
      <!-- Search Input -->
      <div class="px-3 py-2 flex-shrink-0">
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
              $t('CONVERSATION.REPLYBOX.CARD_PICKER.SEARCH_PLACEHOLDER')
            "
            :aria-label="$t('CONVERSATION.REPLYBOX.CARD_PICKER.SEARCH_ARIA')"
            class="w-full h-9 !pl-10 pr-8 text-sm border border-n-slate-6 rounded-lg bg-white dark:bg-n-slate-3 text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:ring-2 focus:ring-n-blue-9 focus:border-transparent"
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
            {{ $t('CONVERSATION.REPLYBOX.CARD_PICKER.ERROR_MESSAGE') }}
          </p>
          <button
            class="text-sm text-n-blue-11 hover:underline"
            @click="searchProducts"
          >
            {{ $t('CONVERSATION.REPLYBOX.CARD_PICKER.RETRY') }}
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
          :aria-label="$t('CONVERSATION.REPLYBOX.CARD_PICKER.RESULTS_ARIA')"
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
            :aria-selected="
              carouselMode ? isProductSelected(product) : index === focusedIndex
            "
            :aria-label="
              carouselMode
                ? $t(
                    'CONVERSATION.REPLYBOX.CARD_PICKER.CAROUSEL_PRODUCT_ARIA',
                    { name: product.item_name }
                  )
                : product.item_name
            "
            tabindex="-1"
            :disabled="carouselMode && isAtLimit && !isProductSelected(product)"
            class="flex items-center w-full px-2 py-2 rounded-lg hover:bg-n-slate-3 cursor-pointer text-left transition-colors"
            :class="{
              'bg-n-slate-3 ring-2 ring-n-blue-9':
                !carouselMode && index === focusedIndex,
              'bg-n-blue-3/50': carouselMode && isProductSelected(product),
              'opacity-50 cursor-not-allowed':
                carouselMode && isAtLimit && !isProductSelected(product),
            }"
            @click="handleProductClick(product)"
          >
            <!-- Carousel checkbox/badge -->
            <div v-if="carouselMode" class="flex-shrink-0 mr-2">
              <div
                v-if="isProductSelected(product)"
                class="w-5 h-5 rounded-full bg-n-blue-9 flex items-center justify-center"
              >
                <span class="text-[10px] font-bold text-white">
                  {{ getProductSelectionIndex(product) + 1 }}
                </span>
              </div>
              <div
                v-else
                class="w-5 h-5 rounded-full border-2 border-n-slate-8"
                :class="{
                  'border-n-slate-6 bg-n-slate-3': isAtLimit,
                }"
              />
            </div>

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

    <!-- Zone 3a: Single card Preview + Send (when product is selected, not carousel) -->
    <template v-if="!carouselMode && selectedProduct && selectedDesign">
      <div class="flex-1 overflow-y-auto p-3 flex items-center justify-center">
        <div class="bg-[#7BC67E] rounded-lg p-3 w-full max-w-[300px]">
          <LineFlexPreview
            :design-json="selectedDesign.design_json"
            :content-data="contentData"
          />
        </div>
      </div>
      <p class="text-center text-xs text-n-slate-9 italic px-3 -mt-1 mb-1">
        {{ $t('CONVERSATION.REPLYBOX.CARD_PICKER.PREVIEW_CAPTION') }}
      </p>
      <div
        class="flex items-center justify-between px-3 py-2 border-t border-n-slate-6 flex-shrink-0"
      >
        <button
          class="text-sm text-n-slate-11 hover:text-n-slate-12"
          @click="goBack"
        >
          {{ $t('CONVERSATION.REPLYBOX.CARD_PICKER.BACK') }}
        </button>
        <Button
          ref="sendButtonRef"
          sm
          solid
          blue
          :is-loading="props.isSending"
          :disabled="props.isSending"
          @click="sendCard"
        >
          {{ $t('CONVERSATION.REPLYBOX.CARD_PICKER.SEND') }}
        </Button>
      </div>
    </template>

    <!-- Zone 3b: Carousel Preview + Send (when carousel mode with selections) -->
    <template
      v-if="carouselMode && selectedProducts.length > 0 && selectedDesign"
    >
      <div
        class="flex-shrink-0 border-t border-n-slate-6 bg-n-slate-2 dark:bg-n-slate-3"
      >
        <!-- Carousel preview strip -->
        <div
          class="flex gap-2 px-3 py-2 overflow-x-auto scroll-smooth bg-[#7BC67E] rounded-md mx-3 mt-2"
        >
          <div
            v-for="(cd, idx) in carouselContentDataList"
            :key="idx"
            class="flex-shrink-0"
          >
            <LineFlexPreview
              :design-json="selectedDesign.design_json"
              :content-data="cd"
              :scale="0.3"
            />
          </div>
        </div>
        <p class="text-center text-xs text-n-slate-9 py-1">
          {{
            $t('CONVERSATION.REPLYBOX.CARD_PICKER.CAROUSEL_PREVIEW_COUNT', {
              count: selectedProducts.length,
            })
          }}
        </p>
        <!-- Send bar -->
        <div
          class="flex items-center justify-between px-3 py-2 border-t border-n-slate-6"
        >
          <button
            class="text-sm text-n-slate-11 hover:text-n-slate-12"
            @click="selectedProducts = []"
          >
            {{ $t('CONVERSATION.REPLYBOX.CARD_PICKER.CLEAR') }}
          </button>
          <div class="flex items-center gap-2">
            <span v-if="!canSendCarousel" class="text-xs text-n-amber-11">
              {{ $t('CONVERSATION.REPLYBOX.CARD_PICKER.CAROUSEL_MIN_HINT') }}
            </span>
            <Button
              ref="sendButtonRef"
              sm
              solid
              blue
              :is-loading="props.isSending"
              :disabled="props.isSending || !canSendCarousel"
              @click="sendCarousel"
            >
              {{
                $t('CONVERSATION.REPLYBOX.CARD_PICKER.SEND_CAROUSEL', {
                  count: selectedProducts.length,
                })
              }}
            </Button>
          </div>
        </div>
      </div>
    </template>

    <!-- Screen reader announcements -->
    <div aria-live="polite" class="sr-only">
      {{ liveMessage }}
    </div>
  </div>
</template>
