<script setup>
import { ref, computed, watch, onMounted, onUnmounted, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import CaptainErpProxy from 'dashboard/api/captain/erpProxy';
import Icon from 'next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import DeliverySection from './DeliverySection.vue';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
  lineUserId: {
    type: String,
    default: '',
  },
  contactName: {
    type: String,
    default: '',
  },
});
const emit = defineEmits(['close', 'send']);
const { t } = useI18n();
const I18N = 'CONVERSATION.REPLYBOX.ORDER_BUILDER';

// State
const searchQuery = ref('');
const searchResults = ref([]);
const isSearching = ref(false);
const hasError = ref(false);
const orderItems = ref([]);
const focusedIndex = ref(-1);
const liveMessage = ref('');
const showDiscardConfirm = ref(false);
const recentlyAdded = ref(new Map());
const highlightedItem = ref('');
const searchInputRef = ref(null);
const productRefs = ref([]);
const isSendingCheckout = ref(false);
const sendError = ref('');
const errorItemCode = ref('');

// Delivery section state
const deliveryState = ref('loading');
const customerData = ref(null);
const selectedAddress = ref(null);
const addressForm = ref({
  name: '',
  phone: '',
  address_line1: '',
  city: '',
  state: '',
  pincode: '',
});
const registerCustomer = ref(false);
let lookupController = null;

// Reset focused index when results change and announce count
watch(searchResults, newResults => {
  focusedIndex.value = -1;
  if (!hasError.value && !isSearching.value) {
    liveMessage.value = t(`${I18N}.RESULTS_ANNOUNCEMENT`, {
      count: newResults.length,
    });
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

// Format line total (price x qty)
const formatLineTotal = item => {
  if (!item.price && item.price !== 0) return '';
  const curr = item.currency || 'THB';
  const total = item.price * item.qty;
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: curr,
      minimumFractionDigits: 0,
      maximumFractionDigits: 2,
    }).format(total);
  } catch {
    return `${curr} ${total}`;
  }
};

// Computed
const hasItems = computed(() => orderItems.value.length > 0);

const totalItemCount = computed(() =>
  orderItems.value.reduce((sum, item) => sum + item.qty, 0)
);

const itemCountLabel = computed(() => {
  const count = totalItemCount.value;
  return count === 1
    ? t(`${I18N}.ITEMS_COUNT_SINGULAR`, { count })
    : t(`${I18N}.ITEMS_COUNT_PLURAL`, { count });
});

const estimatedTotal = computed(() => {
  if (orderItems.value.some(item => item.price == null)) return null;
  return orderItems.value.reduce((sum, item) => sum + item.price * item.qty, 0);
});

const formattedTotal = computed(() => {
  if (estimatedTotal.value === null)
    return t(`${I18N}.ESTIMATED_TOTAL_UNAVAILABLE`);
  const curr = orderItems.value[0]?.currency || 'THB';
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: curr,
      minimumFractionDigits: 0,
      maximumFractionDigits: 2,
    }).format(estimatedTotal.value);
  } catch {
    return `${curr} ${estimatedTotal.value}`;
  }
});

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

// Order management
const addToOrder = product => {
  const existing = orderItems.value.find(
    item => item.item_code === product.item_code
  );
  if (existing) {
    existing.qty += 1;
    // Pulse highlight for duplicate add
    highlightedItem.value = product.item_code;
    setTimeout(() => {
      if (highlightedItem.value === product.item_code) {
        highlightedItem.value = '';
      }
    }, 600);
  } else {
    orderItems.value.push({
      item_code: product.item_code,
      item_name: product.item_name,
      price: product.price,
      currency: product.currency || 'THB',
      image_url: product.image_url || product.image || null,
      stock_status: product.stock_status || 'unknown',
      qty: 1,
    });
  }
  liveMessage.value = t(`${I18N}.ADDED_ANNOUNCEMENT`, {
    name: product.item_name,
  });

  // Checkmark animation: show for 600ms
  const prevTimeout = recentlyAdded.value.get(product.item_code);
  if (prevTimeout) clearTimeout(prevTimeout);
  const timeoutId = setTimeout(() => {
    recentlyAdded.value.delete(product.item_code);
  }, 600);
  recentlyAdded.value.set(product.item_code, timeoutId);
};

const removeFromOrder = itemCode => {
  const item = orderItems.value.find(i => i.item_code === itemCode);
  const itemName = item?.item_name || 'Item';
  orderItems.value = orderItems.value.filter(i => i.item_code !== itemCode);
  liveMessage.value = t(`${I18N}.REMOVED_ANNOUNCEMENT`, { name: itemName });

  // Clear pending checkmark timeout
  const pendingTimeout = recentlyAdded.value.get(itemCode);
  if (pendingTimeout) {
    clearTimeout(pendingTimeout);
    recentlyAdded.value.delete(itemCode);
  }
};

const updateQty = (itemCode, newQty) => {
  const parsed = parseInt(newQty, 10);
  if (Number.isNaN(parsed) || parsed < 1) {
    removeFromOrder(itemCode);
    return;
  }
  const item = orderItems.value.find(i => i.item_code === itemCode);
  if (item) {
    item.qty = parsed;
  }
};

const handleQtyBlur = (itemCode, event) => {
  const parsed = parseInt(event.target.value, 10);
  if (Number.isNaN(parsed) || parsed < 1) {
    // Reset to 1 instead of removing on blur
    const item = orderItems.value.find(i => i.item_code === itemCode);
    if (item) {
      item.qty = 1;
      event.target.value = '1';
    }
  }
};

const decrementQty = itemCode => {
  const item = orderItems.value.find(i => i.item_code === itemCode);
  if (!item) return;
  if (item.qty <= 1) {
    removeFromOrder(itemCode);
  } else {
    item.qty -= 1;
  }
};

const incrementQty = itemCode => {
  const item = orderItems.value.find(i => i.item_code === itemCode);
  if (item) {
    item.qty += 1;
  }
};

const wasRecentlyAdded = itemCode => recentlyAdded.value.has(itemCode);

// Discard confirmation
const handleClose = () => {
  if (hasItems.value) {
    showDiscardConfirm.value = true;
  } else {
    emit('close');
  }
};

const confirmDiscard = () => {
  emit('close');
};

const cancelDiscard = () => {
  showDiscardConfirm.value = false;
};

// Send checkout link
const handleSendCheckout = async () => {
  if (orderItems.value.length === 0 || isSendingCheckout.value) return;

  isSendingCheckout.value = true;
  sendError.value = '';
  errorItemCode.value = '';

  try {
    // Collect delivery data from DeliverySection state
    const deliveryParams = {};

    if (deliveryState.value === 'member' && customerData.value) {
      // Returning member — send customer email + selected/new address
      deliveryParams.customerEmail = customerData.value.customer_email;
      if (selectedAddress.value) {
        deliveryParams.addressName = selectedAddress.value;
      } else {
        // "+ Enter new address" selected — send form data
        const { name: addrName, ...rest } = addressForm.value;
        deliveryParams.addressData = JSON.stringify({
          address_title: addrName,
          ...rest,
        });
      }
    } else if (
      deliveryState.value === 'new_customer' ||
      deliveryState.value === 'no_line'
    ) {
      // New customer — send form data if any field filled
      const form = addressForm.value;
      if (form.name || form.phone || form.address_line1) {
        const { name: addrName, ...rest } = form;
        deliveryParams.addressData = JSON.stringify({
          address_title: addrName,
          ...rest,
        });
      }
      // Registration checkbox
      if (registerCustomer.value && props.lineUserId) {
        deliveryParams.lineUserId = props.lineUserId;
        deliveryParams.registerCustomer = true;
      }
    }

    const { data } = await CaptainErpProxy.createSharedCheckout({
      assistantId: props.assistantId,
      items: orderItems.value.map(item => ({
        item_code: item.item_code,
        qty: item.qty,
      })),
      ...deliveryParams,
    });

    const total = data.grand_total;
    const currency = orderItems.value[0]?.currency || 'THB';
    let formattedAmount;
    try {
      formattedAmount = new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency,
        minimumFractionDigits: 0,
        maximumFractionDigits: 2,
      }).format(total);
    } catch {
      formattedAmount = `${currency} ${total}`;
    }

    const messageText = `${t(`${I18N}.ORDER_READY_MESSAGE`, { total: formattedAmount })}\n${data.url}`;
    liveMessage.value = t(`${I18N}.LINK_SENT_ANNOUNCEMENT`);

    // Show warning if registration failed but link was still created
    if (data.registration_warning) {
      sendError.value = t(`${I18N}.REGISTRATION_WARNING`);
    }

    emit('send', messageText);
  } catch (error) {
    const errorMsg = error?.response?.data?.error || t(`${I18N}.SEND_ERROR`);
    sendError.value = errorMsg;
    liveMessage.value = errorMsg;

    // Highlight specific out-of-stock item
    const stockMatch = errorMsg.match(/Item (\S+) is out of stock/);
    const qtyMatch = errorMsg.match(/available for (\S+)/);
    errorItemCode.value = stockMatch?.[1] || qtyMatch?.[1] || '';

    // Auto-reduce qty if insufficient stock
    const insufficientMatch = errorMsg.match(
      /Only (\d+) units? available for (\S+)/
    );
    if (insufficientMatch) {
      const availableQty = parseInt(insufficientMatch[1], 10);
      const itemCode = insufficientMatch[2];
      errorItemCode.value = itemCode;
      const item = orderItems.value.find(i => i.item_code === itemCode);
      if (item && availableQty > 0) {
        item.qty = availableQty;
      } else if (item && availableQty === 0) {
        removeFromOrder(itemCode);
      }
    }
  } finally {
    isSendingCheckout.value = false;
  }
};

// Keyboard handling
const handleKeydown = event => {
  if (event.key === 'Escape') {
    event.stopPropagation();
    if (showDiscardConfirm.value) {
      cancelDiscard();
    } else if (hasItems.value) {
      showDiscardConfirm.value = true;
    } else {
      emit('close');
    }
    return;
  }

  if (searchResults.value.length === 0) return;

  if (event.key === 'ArrowDown') {
    event.preventDefault();
    focusedIndex.value =
      focusedIndex.value < searchResults.value.length - 1
        ? focusedIndex.value + 1
        : 0;
    productRefs.value[focusedIndex.value]?.scrollIntoView({
      block: 'nearest',
    });
  } else if (event.key === 'ArrowUp') {
    event.preventDefault();
    focusedIndex.value =
      focusedIndex.value > 0
        ? focusedIndex.value - 1
        : searchResults.value.length - 1;
    productRefs.value[focusedIndex.value]?.scrollIntoView({
      block: 'nearest',
    });
  } else if (event.key === 'Enter' && focusedIndex.value >= 0) {
    event.preventDefault();
    addToOrder(searchResults.value[focusedIndex.value]);
  }
};

// Customer lookup for delivery section
const lookupLineCustomer = async () => {
  if (!props.lineUserId) {
    deliveryState.value = 'no_line';
    addressForm.value.name = props.contactName || '';
    return;
  }

  lookupController = new AbortController();
  const timeout = setTimeout(() => lookupController?.abort(), 3000);

  try {
    const { data } = await CaptainErpProxy.lookupLineCustomer({
      assistantId: props.assistantId,
      lineUserId: props.lineUserId,
      signal: lookupController.signal,
    });
    clearTimeout(timeout);

    if (data.is_member) {
      customerData.value = data;
      deliveryState.value = 'member';
      // Pre-select default shipping address, or first address
      const defaultAddr = data.addresses?.find(a => a.is_shipping_address);
      selectedAddress.value =
        defaultAddr?.name || data.addresses?.[0]?.name || null;
    } else {
      deliveryState.value = 'new_customer';
      addressForm.value.name = data.display_name || props.contactName || '';
    }
  } catch {
    clearTimeout(timeout);
    // Silent fallback — show address form (same as non-LINE)
    deliveryState.value = props.lineUserId ? 'new_customer' : 'no_line';
    addressForm.value.name = props.contactName || '';
  }
};

// Lifecycle
onMounted(() => {
  document.addEventListener('keydown', handleKeydown);
  searchProducts();
  lookupLineCustomer();
  nextTick(() => {
    searchInputRef.value?.focus();
  });
});

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeydown);
  // Clean up all pending timeouts
  recentlyAdded.value.forEach(timeoutId => clearTimeout(timeoutId));
  recentlyAdded.value.clear();
  // Abort any pending customer lookup
  lookupController?.abort();
});
</script>

<template>
  <div
    class="flex flex-col bg-white dark:bg-n-slate-2 border-t border-n-slate-6 h-[520px]"
  >
    <!-- Header -->
    <div
      class="flex items-center justify-between px-3 py-2 border-b border-n-slate-6 flex-shrink-0"
    >
      <span class="text-sm font-semibold text-n-slate-12">
        {{ $t(`${I18N}.TITLE`) }}
      </span>
      <button
        :aria-label="t(`${I18N}.CLOSE_ARIA`)"
        class="p-1 rounded hover:bg-n-slate-3 text-n-slate-11"
        @click="handleClose"
      >
        <Icon icon="i-lucide-x" size="16" />
      </button>
    </div>

    <!-- Discard confirmation banner -->
    <div
      v-if="showDiscardConfirm"
      class="flex items-center justify-between px-3 py-2 bg-n-amber-2 border-b border-n-amber-6 flex-shrink-0"
    >
      <span class="text-sm text-n-amber-11">
        {{ $t(`${I18N}.DISCARD_MESSAGE`, { count: orderItems.length }) }}
      </span>
      <div class="flex items-center gap-2">
        <button
          class="text-sm text-n-slate-11 hover:text-n-slate-12 px-2 py-1 rounded hover:bg-n-slate-3"
          @click="cancelDiscard"
        >
          {{ $t(`${I18N}.KEEP_BUILDING`) }}
        </button>
        <button
          class="text-sm text-n-ruby-11 hover:text-n-ruby-12 px-2 py-1 rounded hover:bg-n-ruby-3"
          @click="confirmDiscard"
        >
          {{ $t(`${I18N}.DISCARD`) }}
        </button>
      </div>
    </div>

    <!-- TOP ZONE: Search + Results -->
    <div class="flex flex-col flex-1 min-h-0">
      <!-- Search Input -->
      <div class="px-3 py-2 flex-shrink-0">
        <div class="relative">
          <Icon
            icon="i-lucide-search"
            size="16"
            class="absolute left-2.5 top-1/2 -translate-y-1/2 text-n-slate-9"
          />
          <input
            ref="searchInputRef"
            v-model="searchQuery"
            type="text"
            :placeholder="t(`${I18N}.SEARCH_PLACEHOLDER`)"
            :aria-label="t(`${I18N}.SEARCH_ARIA`)"
            class="w-full h-9 pl-8 pr-8 text-sm border border-n-slate-6 rounded-lg bg-white dark:bg-n-slate-3 text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:ring-2 focus:ring-n-blue-9 focus:border-transparent"
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
            :size="16"
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
            {{ $t(`${I18N}.ERROR_MESSAGE`) }}
          </p>
          <button
            class="text-sm text-n-blue-11 hover:underline"
            @click="searchProducts"
          >
            {{ $t(`${I18N}.RETRY`) }}
          </button>
        </div>

        <!-- Empty state -->
        <div
          v-else-if="!isSearching && searchResults.length === 0"
          class="flex flex-col items-center justify-center h-full text-center px-4"
        >
          <Icon icon="i-lucide-search" size="24" class="text-n-slate-9 mb-2" />
          <p class="text-sm text-n-slate-11">
            <template v-if="searchQuery">
              {{ $t(`${I18N}.NO_RESULTS`, { query: searchQuery }) }}
            </template>
            <template v-else>
              {{ $t(`${I18N}.NO_PRODUCTS`) }}
            </template>
          </p>
        </div>

        <!-- Product list -->
        <div v-else role="listbox" :aria-label="t(`${I18N}.RESULTS_ARIA`)">
          <div
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
            <div class="flex items-center gap-1.5 flex-shrink-0 mr-2">
              <span
                v-if="formatListPrice(product)"
                class="text-sm text-n-slate-11"
              >
                {{ formatListPrice(product) }}
              </span>
              <span v-else class="text-xs text-n-slate-9">
                {{ $t(`${I18N}.PRICE_UNAVAILABLE`) }}
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

            <!-- Add button -->
            <button
              :aria-label="t(`${I18N}.ADD_ARIA`, { name: product.item_name })"
              class="flex-shrink-0 w-7 h-7 rounded-full flex items-center justify-center transition-all duration-200"
              :class="
                wasRecentlyAdded(product.item_code)
                  ? 'bg-n-green-3 text-n-green-11'
                  : 'bg-n-slate-3 hover:bg-n-blue-3 text-n-slate-11 hover:text-n-blue-11'
              "
              @click.stop="addToOrder(product)"
            >
              <Icon
                :icon="
                  wasRecentlyAdded(product.item_code)
                    ? 'i-lucide-check'
                    : 'i-lucide-plus'
                "
                size="14"
              />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- BOTTOM ZONE: Order Summary -->
    <div
      class="border-t border-n-slate-6 flex-shrink-0 flex flex-col max-h-[300px]"
    >
      <!-- Order label -->
      <div class="px-3 pt-2 pb-1">
        <span
          class="text-xs font-semibold text-n-slate-9 uppercase tracking-wide"
        >
          {{ $t(`${I18N}.ORDER_LABEL`) }}
        </span>
      </div>

      <!-- Empty summary -->
      <div v-if="!hasItems" class="px-3 pb-2">
        <div
          class="flex items-center justify-center py-4 border border-dashed border-n-slate-6 rounded-lg"
        >
          <span class="text-sm text-n-slate-9">
            {{ $t(`${I18N}.EMPTY_ORDER`) }}
          </span>
        </div>

        <!-- Delivery section (visible even when no items yet) -->
        <DeliverySection
          :lookup-state="deliveryState"
          :customer-data="customerData"
          :selected-address="selectedAddress"
          :address-form="addressForm"
          :register-customer="registerCustomer"
          :assistant-id="assistantId"
          @select-address="selectedAddress = $event"
          @update:address-form="addressForm = $event"
          @update:register-customer="registerCustomer = $event"
        />
      </div>

      <!-- Order items -->
      <template v-else>
        <div class="flex-1 overflow-y-auto min-h-0">
          <TransitionGroup name="order-item" tag="div" class="relative px-2">
            <div
              v-for="item in orderItems"
              :key="item.item_code"
              class="flex items-center py-1.5 px-1 rounded hover:bg-n-slate-3"
              :class="{
                'border-l-2 border-n-ruby-9': errorItemCode === item.item_code,
                'animate-pulse-highlight': highlightedItem === item.item_code,
              }"
            >
              <!-- Small thumbnail -->
              <div
                class="flex-shrink-0 w-6 h-6 rounded bg-n-slate-3 overflow-hidden mr-2"
              >
                <img
                  v-if="item.image_url"
                  :src="item.image_url"
                  :alt="item.item_name"
                  class="w-full h-full object-cover"
                />
                <div
                  v-else
                  class="w-full h-full flex items-center justify-center"
                >
                  <Icon
                    icon="i-lucide-package"
                    size="10"
                    class="text-n-slate-9"
                  />
                </div>
              </div>

              <!-- Name -->
              <div class="flex-1 min-w-0 mr-2">
                <p class="text-xs text-n-slate-12 truncate">
                  {{ item.item_name }}
                </p>
              </div>

              <!-- Quantity stepper -->
              <div class="flex items-center gap-0.5 mr-2 flex-shrink-0">
                <button
                  :aria-label="
                    t(`${I18N}.DECREASE_QTY_ARIA`, { name: item.item_name })
                  "
                  class="w-5 h-5 rounded-full flex items-center justify-center bg-n-slate-3 hover:bg-n-slate-4 text-n-slate-11"
                  @click="decrementQty(item.item_code)"
                >
                  <Icon icon="i-lucide-minus" size="10" />
                </button>
                <input
                  type="number"
                  min="1"
                  :value="item.qty"
                  :aria-label="t(`${I18N}.QTY_ARIA`, { name: item.item_name })"
                  class="w-8 h-5 text-center text-xs font-medium border border-n-slate-6 rounded bg-white dark:bg-n-slate-3 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-blue-9 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                  @change="updateQty(item.item_code, $event.target.value)"
                  @blur="handleQtyBlur(item.item_code, $event)"
                  @wheel.prevent
                />
                <button
                  :aria-label="
                    t(`${I18N}.INCREASE_QTY_ARIA`, { name: item.item_name })
                  "
                  class="w-5 h-5 rounded-full flex items-center justify-center bg-n-slate-3 hover:bg-n-slate-4 text-n-slate-11"
                  @click="incrementQty(item.item_code)"
                >
                  <Icon icon="i-lucide-plus" size="10" />
                </button>
              </div>

              <!-- Line total -->
              <span
                v-if="formatLineTotal(item)"
                class="text-xs text-n-slate-11 mr-2 flex-shrink-0 w-16 text-right"
              >
                {{ formatLineTotal(item) }}
              </span>
              <span v-else class="text-xs text-n-slate-9 mr-2 flex-shrink-0">
                --
              </span>

              <!-- Remove button -->
              <button
                :aria-label="t(`${I18N}.REMOVE_ARIA`, { name: item.item_name })"
                class="flex-shrink-0 w-5 h-5 rounded flex items-center justify-center text-n-slate-9 hover:text-n-ruby-11 hover:bg-n-ruby-3"
                @click="removeFromOrder(item.item_code)"
              >
                <Icon icon="i-lucide-x" size="12" />
              </button>
            </div>
          </TransitionGroup>

          <!-- Delivery section -->
          <DeliverySection
            :lookup-state="deliveryState"
            :customer-data="customerData"
            :selected-address="selectedAddress"
            :address-form="addressForm"
            :register-customer="registerCustomer"
            :assistant-id="assistantId"
            @select-address="selectedAddress = $event"
            @update:address-form="addressForm = $event"
            @update:register-customer="registerCustomer = $event"
          />
        </div>

        <!-- Summary footer (pinned at bottom) -->
        <div class="px-3 py-2 border-t border-n-slate-6">
          <div class="flex items-center justify-between mb-2">
            <span class="text-xs text-n-slate-11">
              {{ itemCountLabel }}
            </span>
            <div class="text-right">
              <span class="text-sm font-semibold text-n-slate-12">
                {{ formattedTotal }}
              </span>
              <p
                v-if="estimatedTotal !== null"
                class="text-[10px] text-n-slate-9"
              >
                {{ $t(`${I18N}.ESTIMATED_TOTAL`) }}
              </p>
            </div>
          </div>
          <div
            v-if="sendError"
            class="mb-2 px-3 py-2 rounded-lg bg-n-ruby-3 text-n-ruby-11 text-xs"
          >
            {{ sendError }}
          </div>
          <Button
            sm
            solid
            blue
            class="w-full"
            :disabled="!hasItems || isSendingCheckout"
            :is-loading="isSendingCheckout"
            @click="handleSendCheckout"
          >
            {{ $t(`${I18N}.SEND_BUTTON`) }}
          </Button>
        </div>
      </template>
    </div>

    <!-- Screen reader announcements -->
    <div aria-live="polite" class="sr-only">
      {{ liveMessage }}
    </div>
  </div>
</template>

<style scoped>
.order-item-enter-active {
  transition: all 0.2s ease-out;
}
.order-item-leave-active {
  transition: all 0.15s ease-in;
  position: absolute;
  width: calc(100% - 16px);
}
.order-item-enter-from {
  opacity: 0;
  transform: translateX(20px);
}
.order-item-leave-to {
  opacity: 0;
  transform: translateX(-20px);
}
.order-item-move {
  transition: transform 0.2s ease-out;
}

@keyframes pulse-highlight {
  0%,
  100% {
    background-color: transparent;
  }
  50% {
    background-color: var(--n-blue-3);
  }
}
.animate-pulse-highlight {
  animation: pulse-highlight 0.6s ease-in-out;
}

@media (prefers-reduced-motion: reduce) {
  .order-item-enter-active,
  .order-item-leave-active,
  .order-item-move {
    transition-duration: 0s;
  }
  .animate-pulse-highlight {
    animation: none;
    background-color: var(--n-blue-3);
  }
}
</style>
