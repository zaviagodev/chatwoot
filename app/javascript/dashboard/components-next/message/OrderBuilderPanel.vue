<script setup>
import {
  ref,
  computed,
  watch,
  onMounted,
  onUnmounted,
  nextTick,
  provide,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import CaptainErpProxy from 'dashboard/api/captain/erpProxy';
import Icon from 'next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import DeliverySection from './DeliverySection.vue';
import VariantPickerSheet from './VariantPickerSheet.vue';
import PersonalizationFormSheet from './PersonalizationFormSheet.vue';
import BundleConfigSheet from './BundleConfigSheet.vue';

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

// Variant picker state
const showVariantPicker = ref(false);
const variantPickerProduct = ref(null);

// Personalization form state
const showPersonalizationForm = ref(false);
const personalizationProduct = ref(null);
const personalizationVariantData = ref(null);

// Bundle config state
const showBundleConfig = ref(false);
const bundleConfigProduct = ref(null);

// Session-level API response caches (auto-cleared on panel unmount via v-if)
const variantCache = new Map();
const customizationCache = new Map();
const bundleCache = new Map();
provide('variantCache', variantCache);
provide('customizationCache', customizationCache);
provide('bundleCache', bundleCache);

// Combined flow + edit mode state
const pendingVariantSelections = ref(null); // {Size: "M"} map for back nav
const editingItemId = ref(null); // UUID of item being edited
const expandedItems = ref(new Set()); // expanded personalization summaries
const pendingPersonalizationValues = ref(null); // {label: value} map for edit
const pendingBundleSelections = ref(null); // edit mode bundle selections

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

// Format line total (price x qty), including addon surcharges
const formatLineTotal = item => {
  if (!item.price && item.price !== 0) return '';
  const curr = item.currency || 'THB';
  const total = (item.price + (item.addon_total || 0)) * item.qty;
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
  return orderItems.value.reduce(
    (sum, item) => sum + (item.price + (item.addon_total || 0)) * item.qty,
    0
  );
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
  // Non-personalized items can merge by item_code
  const existing = orderItems.value.find(
    item => item.item_code === product.item_code && !item.customizations
  );
  if (existing) {
    existing.qty += 1;
    highlightedItem.value = existing.id;
    setTimeout(() => {
      if (highlightedItem.value === existing.id) {
        highlightedItem.value = '';
      }
    }, 600);
  } else {
    const id = crypto.randomUUID();
    orderItems.value.push({
      id,
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

  const itemId = orderItems.value.find(
    i => i.item_code === product.item_code
  )?.id;
  if (itemId) {
    const prevTimeout = recentlyAdded.value.get(itemId);
    if (prevTimeout) clearTimeout(prevTimeout);
    const timeoutId = setTimeout(() => {
      recentlyAdded.value.delete(itemId);
    }, 600);
    recentlyAdded.value.set(itemId, timeoutId);
  }
};

// Handle product click — bundle first, then variant picker, personalization, or direct add
const handleProductClick = product => {
  // Bundle check FIRST — a bundle parent can also have has_customization=true
  if (product.is_bundle) {
    bundleConfigProduct.value = product;
    showBundleConfig.value = true;
  } else if (product.has_variants && product.variant_count > 0) {
    variantPickerProduct.value = product;
    showVariantPicker.value = true;
  } else if (product.has_customization) {
    // Personalization only (no variants) — open personalization form directly
    personalizationProduct.value = product;
    personalizationVariantData.value = null;
    showPersonalizationForm.value = true;
  } else {
    addToOrder(product);
  }
};

// Handle variant selection from picker sheet
const handleVariantAdd = variantData => {
  // variantData: { item_code, item_name, price, currency, image, selected_options, stock_status }
  const hasCustomization = variantPickerProduct.value?.has_customization;

  // Combined flow: product has personalization → transition to personalization form
  if (hasCustomization) {
    // Convert selected_options array to map for back navigation
    const map = {};
    (variantData.selected_options || []).forEach(o => {
      map[o.name] = o.value;
    });
    pendingVariantSelections.value = map;

    personalizationVariantData.value = variantData;
    personalizationProduct.value = variantPickerProduct.value;
    showVariantPicker.value = false;
    // editingItemId persists across transition if in edit mode
    showPersonalizationForm.value = true;
    return;
  }

  // Variant-only: edit mode → update existing item
  if (editingItemId.value) {
    const existing = orderItems.value.find(i => i.id === editingItemId.value);
    if (existing) {
      existing.item_code = variantData.item_code;
      existing.item_name = variantData.item_name;
      existing.price = variantData.price;
      existing.currency = variantData.currency || 'THB';
      existing.image_url = variantData.image || null;
      existing.stock_status = variantData.stock_status || 'in_stock';
      existing.selected_options = variantData.selected_options || [];
    }
    editingItemId.value = null;
    showVariantPicker.value = false;
    variantPickerProduct.value = null;
    pendingVariantSelections.value = null;
    return;
  }

  // Variant-only: normal add — non-personalized variants can merge by item_code
  const existing = orderItems.value.find(
    item => item.item_code === variantData.item_code && !item.customizations
  );
  if (existing) {
    existing.qty += 1;
    highlightedItem.value = existing.id;
    setTimeout(() => {
      if (highlightedItem.value === existing.id) {
        highlightedItem.value = '';
      }
    }, 600);
  } else {
    const id = crypto.randomUUID();
    orderItems.value.push({
      id,
      item_code: variantData.item_code,
      item_name: variantData.item_name,
      price: variantData.price,
      currency: variantData.currency || 'THB',
      image_url: variantData.image || null,
      stock_status: variantData.stock_status || 'in_stock',
      qty: 1,
      selected_options: variantData.selected_options || [],
      // Store template item_code for edit mode (variant code differs from template)
      template_item_code: variantPickerProduct.value?.item_code || null,
    });
  }
  liveMessage.value = t(`${I18N}.ADDED_ANNOUNCEMENT`, {
    name: variantData.item_name,
  });
  showVariantPicker.value = false;
  variantPickerProduct.value = null;
  pendingVariantSelections.value = null;
};

// Handle personalization add from form sheet
const handlePersonalizationAdd = data => {
  // data: { item_code, item_name, price, currency, image, selected_options, customizations, addon_total, customization_summary, stock_status }

  let itemId;

  // Edit mode: update existing item in place (keep UUID)
  if (editingItemId.value) {
    const existing = orderItems.value.find(i => i.id === editingItemId.value);
    if (existing) {
      existing.item_code = data.item_code;
      existing.item_name = data.item_name;
      existing.price = data.price;
      existing.currency = data.currency || 'THB';
      existing.image_url = data.image || null;
      existing.stock_status = data.stock_status || 'in_stock';
      existing.selected_options = data.selected_options || [];
      existing.customizations = data.customizations;
      existing.addon_total = data.addon_total || 0;
      existing.customization_summary = data.customization_summary || '';
      itemId = existing.id;
    }
    editingItemId.value = null;
  } else {
    // New item
    itemId = crypto.randomUUID();
    orderItems.value.push({
      id: itemId,
      item_code: data.item_code,
      item_name: data.item_name,
      price: data.price,
      currency: data.currency || 'THB',
      image_url: data.image || null,
      stock_status: data.stock_status || 'in_stock',
      qty: 1,
      selected_options: data.selected_options || [],
      customizations: data.customizations,
      addon_total: data.addon_total || 0,
      customization_summary: data.customization_summary || '',
      // Store template item_code for edit mode
      template_item_code: personalizationProduct.value?.item_code || null,
    });
  }

  liveMessage.value = t(`${I18N}.ADDED_ANNOUNCEMENT`, {
    name: data.item_name,
  });
  showPersonalizationForm.value = false;
  personalizationProduct.value = null;
  personalizationVariantData.value = null;
  pendingVariantSelections.value = null;
  pendingPersonalizationValues.value = null;

  // Checkmark animation
  if (itemId) {
    const prevTimeout = recentlyAdded.value.get(itemId);
    if (prevTimeout) clearTimeout(prevTimeout);
    const timeoutId = setTimeout(() => {
      recentlyAdded.value.delete(itemId);
    }, 600);
    recentlyAdded.value.set(itemId, timeoutId);
  }
};

const closePersonalizationForm = () => {
  showPersonalizationForm.value = false;
  personalizationProduct.value = null;
  personalizationVariantData.value = null;
  editingItemId.value = null;
  pendingVariantSelections.value = null;
  pendingPersonalizationValues.value = null;
};

// Handle bundle add from BundleConfigSheet
const handleBundleAdd = data => {
  let itemId;

  if (editingItemId.value) {
    const existing = orderItems.value.find(i => i.id === editingItemId.value);
    if (existing) {
      existing.item_code = data.item_code;
      existing.item_name = data.item_name;
      existing.price = data.price;
      existing.currency = data.currency || 'THB';
      existing.image_url = data.image || null;
      existing.stock_status = data.stock_status || 'in_stock';
      existing.is_bundle = true;
      existing.bundle_variant_selections = data.bundle_variant_selections;
      existing.bundle_children_summary = data.bundle_children_summary || '';
      existing.customizations = data.customizations;
      existing.addon_total = data.addon_total || 0;
      existing.customization_summary = data.customization_summary || '';
      existing.selected_options = [];
      itemId = existing.id;
    }
    editingItemId.value = null;
  } else {
    itemId = crypto.randomUUID();
    orderItems.value.push({
      id: itemId,
      item_code: data.item_code,
      item_name: data.item_name,
      price: data.price,
      currency: data.currency || 'THB',
      image_url: data.image || null,
      stock_status: data.stock_status || 'in_stock',
      qty: 1,
      is_bundle: true,
      bundle_variant_selections: data.bundle_variant_selections,
      bundle_children_summary: data.bundle_children_summary || '',
      customizations: data.customizations,
      addon_total: data.addon_total || 0,
      customization_summary: data.customization_summary || '',
      selected_options: [],
      template_item_code: data.item_code,
    });
  }

  liveMessage.value = t(`${I18N}.ADDED_ANNOUNCEMENT`, {
    name: data.item_name,
  });
  showBundleConfig.value = false;
  bundleConfigProduct.value = null;
  pendingBundleSelections.value = null;
  pendingPersonalizationValues.value = null;

  if (itemId) {
    const prevTimeout = recentlyAdded.value.get(itemId);
    if (prevTimeout) clearTimeout(prevTimeout);
    const timeoutId = setTimeout(() => {
      recentlyAdded.value.delete(itemId);
    }, 600);
    recentlyAdded.value.set(itemId, timeoutId);
  }
};

const closeBundleConfig = () => {
  showBundleConfig.value = false;
  bundleConfigProduct.value = null;
  editingItemId.value = null;
  pendingBundleSelections.value = null;
  pendingPersonalizationValues.value = null;
};

const closeVariantPicker = () => {
  showVariantPicker.value = false;
  variantPickerProduct.value = null;
  editingItemId.value = null;
  pendingVariantSelections.value = null;
};

// Back from personalization → re-open variant picker with preserved selections
const handlePersonalizationBack = () => {
  showPersonalizationForm.value = false;
  personalizationVariantData.value = null;
  // Re-open variant picker with the same product + preserved selections
  variantPickerProduct.value = personalizationProduct.value;
  showVariantPicker.value = true;
  // editingItemId persists — still in edit flow
};

// Edit a configured item — re-open the appropriate sheet(s)
const handleEditItem = item => {
  // Bundle items — detect via is_bundle flag (NOT bundle_variant_selections presence)
  if (item.is_bundle) {
    editingItemId.value = item.id;
    pendingBundleSelections.value = item.bundle_variant_selections
      ? { ...item.bundle_variant_selections }
      : null;
    if (item.customizations) {
      pendingPersonalizationValues.value = { ...item.customizations };
    }
    const templateCode = item.template_item_code || item.item_code;
    bundleConfigProduct.value = searchResults.value.find(
      p => p.item_code === templateCode
    ) || {
      item_code: templateCode,
      item_name: item.item_name,
      image_url: item.image_url,
      price: item.price,
      currency: item.currency,
      is_bundle: true,
    };
    showBundleConfig.value = true;
    return;
  }

  const hasVariants = item.selected_options && item.selected_options.length > 0;
  const hasCustomizations =
    item.customizations && Object.keys(item.customizations).length > 0;

  if (!hasVariants && !hasCustomizations) return; // Simple item — nothing to edit

  editingItemId.value = item.id;

  // Convert selected_options array to map for initialSelections
  if (hasVariants) {
    const map = {};
    item.selected_options.forEach(o => {
      map[o.name] = o.value;
    });
    pendingVariantSelections.value = map;
  }

  // Store personalization values for edit
  if (hasCustomizations) {
    pendingPersonalizationValues.value = { ...item.customizations };
  }

  // Find the original template product from search results or reconstruct it
  const templateCode = item.template_item_code || item.item_code;
  const searchProduct = searchResults.value.find(
    p => p.item_code === templateCode
  );

  if (hasVariants) {
    variantPickerProduct.value = searchProduct || {
      item_code: templateCode,
      item_name: item.item_name.split(' — ')[0] || item.item_name,
      image_url: item.image_url,
      has_customization: hasCustomizations,
      has_variants: true,
    };
    showVariantPicker.value = true;
  } else {
    personalizationProduct.value = searchProduct || {
      item_code: templateCode,
      item_name: item.item_name,
      image_url: item.image_url,
      has_customization: true,
    };
    personalizationVariantData.value = null;
    showPersonalizationForm.value = true;
  }
};

// Toggle expanded personalization summary
const toggleExpand = itemId => {
  if (expandedItems.value.has(itemId)) {
    expandedItems.value.delete(itemId);
  } else {
    expandedItems.value.add(itemId);
  }
};

const removeFromOrder = itemId => {
  const item = orderItems.value.find(i => i.id === itemId);
  const itemName = item?.item_name || 'Item';
  orderItems.value = orderItems.value.filter(i => i.id !== itemId);
  liveMessage.value = t(`${I18N}.REMOVED_ANNOUNCEMENT`, { name: itemName });

  const pendingTimeout = recentlyAdded.value.get(itemId);
  if (pendingTimeout) {
    clearTimeout(pendingTimeout);
    recentlyAdded.value.delete(itemId);
  }
};

const updateQty = (itemId, newQty) => {
  const parsed = parseInt(newQty, 10);
  if (Number.isNaN(parsed) || parsed < 1) {
    removeFromOrder(itemId);
    return;
  }
  const item = orderItems.value.find(i => i.id === itemId);
  if (item) {
    item.qty = parsed;
  }
};

const handleQtyBlur = (itemId, event) => {
  const parsed = parseInt(event.target.value, 10);
  if (Number.isNaN(parsed) || parsed < 1) {
    const item = orderItems.value.find(i => i.id === itemId);
    if (item) {
      item.qty = 1;
      event.target.value = '1';
    }
  }
};

const decrementQty = itemId => {
  const item = orderItems.value.find(i => i.id === itemId);
  if (!item) return;
  if (item.qty <= 1) {
    removeFromOrder(itemId);
  } else {
    item.qty -= 1;
  }
};

const incrementQty = itemId => {
  const item = orderItems.value.find(i => i.id === itemId);
  if (item) {
    item.qty += 1;
  }
};

// Check if product was recently added (for search results, looks up by item_code)
const wasProductRecentlyAdded = itemCode => {
  const item = orderItems.value.find(i => i.item_code === itemCode);
  return item ? recentlyAdded.value.has(item.id) : false;
};

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
      items: orderItems.value.map(item => {
        const payload = { item_code: item.item_code, qty: item.qty };
        if (item.customizations) {
          payload.customizations = item.customizations;
        }
        if (item.bundle_variant_selections) {
          payload.bundle_variant_selections = item.bundle_variant_selections;
        }
        return payload;
      }),
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
  } catch (err) {
    // Frappe sends validation errors in _server_messages (double-encoded JSON),
    // NOT in .error. Parse _server_messages first, fall back to .error, then i18n default.
    let errorMsg = '';
    // eslint-disable-next-line no-underscore-dangle
    const serverMsgs = err?.response?.data?._server_messages;
    if (serverMsgs) {
      try {
        const parsed = JSON.parse(serverMsgs);
        const firstMsg = parsed?.[0] ? JSON.parse(parsed[0]) : null;
        errorMsg = firstMsg?.message || '';
      } catch {
        errorMsg = '';
      }
    }
    if (!errorMsg) {
      errorMsg = err?.response?.data?.error || t(`${I18N}.SEND_ERROR`);
    }
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
      const matchedCode = insufficientMatch[2];
      errorItemCode.value = matchedCode;
      const item = orderItems.value.find(i => i.item_code === matchedCode);
      if (item && availableQty > 0) {
        item.qty = availableQty;
      } else if (item && availableQty === 0) {
        removeFromOrder(item.id);
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
    // Close sheets first before triggering discard dialog
    // Priority: bundle config → variant picker → personalization → discard
    if (showBundleConfig.value) {
      closeBundleConfig();
      return;
    }
    if (showVariantPicker.value) {
      closeVariantPicker();
      return;
    }
    if (showPersonalizationForm.value) {
      closePersonalizationForm();
      return;
    }
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
    handleProductClick(searchResults.value[focusedIndex.value]);
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
            class="absolute left-3 top-1/2 -translate-y-1/2 text-n-slate-9"
          />
          <input
            ref="searchInputRef"
            v-model="searchQuery"
            type="text"
            :placeholder="t(`${I18N}.SEARCH_PLACEHOLDER`)"
            :aria-label="t(`${I18N}.SEARCH_ARIA`)"
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
            @click="handleProductClick(product)"
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

            <!-- Name + variant badge -->
            <div class="flex-1 min-w-0 mr-2">
              <p class="text-sm text-n-slate-12 truncate leading-tight">
                {{ product.item_name }}
              </p>
              <div class="flex gap-1 mt-0.5">
                <span
                  v-if="product.has_variants && product.variant_count > 0"
                  class="inline-block text-[10px] text-n-slate-9 bg-n-slate-3 px-1.5 py-0.5 rounded"
                >
                  <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
                  {{ product.variant_count }} variants
                </span>
                <!-- eslint-disable vue/no-bare-strings-in-template -->
                <span
                  v-if="product.is_bundle"
                  class="inline-block text-[10px] text-n-slate-9 bg-n-slate-3 px-1.5 py-0.5 rounded"
                >
                  Bundle
                </span>
                <span
                  v-if="product.has_customization"
                  class="inline-block text-[10px] text-n-slate-9 bg-n-slate-3 px-1.5 py-0.5 rounded"
                >
                  Personalizable
                </span>
                <!-- eslint-enable vue/no-bare-strings-in-template -->
              </div>
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
                wasProductRecentlyAdded(product.item_code)
                  ? 'bg-n-green-3 text-n-green-11'
                  : 'bg-n-slate-3 hover:bg-n-blue-3 text-n-slate-11 hover:text-n-blue-11'
              "
              @click.stop="handleProductClick(product)"
            >
              <Icon
                :icon="
                  wasProductRecentlyAdded(product.item_code)
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
              :key="item.id"
              class="flex items-start py-1.5 px-1 rounded hover:bg-n-slate-3"
              :class="{
                'border-l-2 border-n-ruby-9': errorItemCode === item.item_code,
                'animate-pulse-highlight': highlightedItem === item.id,
                'cursor-pointer':
                  item.is_bundle ||
                  item.selected_options?.length ||
                  item.customizations,
              }"
              @click="handleEditItem(item)"
            >
              <!-- Small thumbnail -->
              <div
                class="flex-shrink-0 w-6 h-6 rounded bg-n-slate-3 overflow-hidden mr-2 mt-0.5"
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

              <!-- Name + config summary -->
              <div class="flex-1 min-w-0 mr-2">
                <p class="text-xs text-n-slate-12 truncate">
                  {{ item.item_name }}
                </p>
                <!-- Bundle children summary -->
                <p
                  v-if="item.bundle_children_summary"
                  class="text-[10px] text-n-slate-9 truncate"
                >
                  {{ item.bundle_children_summary }}
                </p>
                <!-- Variant attributes: compact "M / Blue" format -->
                <p
                  v-if="
                    !item.is_bundle &&
                    item.selected_options &&
                    item.selected_options.length
                  "
                  class="text-[10px] text-n-slate-9 truncate"
                >
                  {{ item.selected_options.map(o => o.value).join(' / ') }}
                </p>
                <!-- Personalization summary -->
                <template v-if="item.customizations">
                  <p class="text-[10px] text-n-slate-9 truncate">
                    {{ item.customization_summary }}
                  </p>
                  <!-- Expanded details -->
                  <div
                    v-if="expandedItems.has(item.id) && item.customizations"
                    class="mt-0.5"
                  >
                    <p
                      v-for="(val, label) in item.customizations"
                      :key="label"
                      class="text-[10px] text-n-slate-9 truncate"
                    >
                      {{ label }}: {{ val === '1' ? 'Yes' : val || '-' }}
                    </p>
                  </div>
                  <!-- "+N more" toggle -->
                  <button
                    v-if="
                      item.customizations &&
                      Object.keys(item.customizations).length > 2
                    "
                    class="text-[10px] text-n-blue-11 hover:underline mt-0.5"
                    @click.stop="toggleExpand(item.id)"
                  >
                    <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
                    {{
                      expandedItems.has(item.id)
                        ? 'Show less'
                        : `+${Object.keys(item.customizations).length - 2} more`
                    }}
                  </button>
                </template>
                <!-- Edit hint for configured items -->
                <p
                  v-if="
                    (item.selected_options?.length || item.customizations) &&
                    !expandedItems.has(item.id)
                  "
                  class="text-[10px] text-n-blue-11 opacity-0 group-hover:opacity-100 transition-opacity"
                />
              </div>

              <!-- Quantity stepper -->
              <div class="flex items-center gap-0.5 mr-2 flex-shrink-0">
                <button
                  :aria-label="
                    t(`${I18N}.DECREASE_QTY_ARIA`, { name: item.item_name })
                  "
                  class="w-5 h-5 rounded-full flex items-center justify-center bg-n-slate-3 hover:bg-n-slate-4 text-n-slate-11"
                  @click.stop="decrementQty(item.id)"
                >
                  <Icon icon="i-lucide-minus" size="10" />
                </button>
                <input
                  type="number"
                  min="1"
                  :value="item.qty"
                  :aria-label="t(`${I18N}.QTY_ARIA`, { name: item.item_name })"
                  class="w-8 h-5 text-center text-xs font-medium border border-n-slate-6 rounded bg-white dark:bg-n-slate-3 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-blue-9 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                  @click.stop
                  @change="updateQty(item.id, $event.target.value)"
                  @blur="handleQtyBlur(item.id, $event)"
                  @wheel.prevent
                />
                <button
                  :aria-label="
                    t(`${I18N}.INCREASE_QTY_ARIA`, { name: item.item_name })
                  "
                  class="w-5 h-5 rounded-full flex items-center justify-center bg-n-slate-3 hover:bg-n-slate-4 text-n-slate-11"
                  @click.stop="incrementQty(item.id)"
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
                @click.stop="removeFromOrder(item.id)"
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

    <!-- Variant Picker Sheet (overlays bottom of panel) -->
    <Transition name="variant-sheet">
      <VariantPickerSheet
        v-if="showVariantPicker && variantPickerProduct"
        :product="variantPickerProduct"
        :assistant-id="assistantId"
        :has-customization="variantPickerProduct.has_customization || false"
        :initial-selections="pendingVariantSelections"
        @add="handleVariantAdd"
        @close="closeVariantPicker"
      />
    </Transition>

    <!-- Personalization Form Sheet (overlays bottom of panel) -->
    <Transition name="variant-sheet">
      <PersonalizationFormSheet
        v-if="showPersonalizationForm && personalizationProduct"
        :product="personalizationProduct"
        :assistant-id="assistantId"
        :variant-data="personalizationVariantData"
        :initial-values="pendingPersonalizationValues"
        :is-editing="!!editingItemId"
        @add="handlePersonalizationAdd"
        @close="closePersonalizationForm"
        @back="handlePersonalizationBack"
      />
    </Transition>

    <!-- Bundle Config Sheet (overlays bottom of panel) -->
    <Transition name="variant-sheet">
      <BundleConfigSheet
        v-if="showBundleConfig && bundleConfigProduct"
        :product="bundleConfigProduct"
        :assistant-id="assistantId"
        :initial-bundle-selections="pendingBundleSelections"
        :initial-personalization-values="pendingPersonalizationValues"
        :is-editing="!!editingItemId"
        @add="handleBundleAdd"
        @close="closeBundleConfig"
      />
    </Transition>

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

/* Variant sheet slide-up transition */
.variant-sheet-enter-active {
  transition:
    transform 0.2s ease-out,
    opacity 0.2s ease-out;
}
.variant-sheet-leave-active {
  transition:
    transform 0.15s ease-in,
    opacity 0.15s ease-in;
}
.variant-sheet-enter-from,
.variant-sheet-leave-to {
  transform: translateY(100%);
  opacity: 0;
}
</style>
