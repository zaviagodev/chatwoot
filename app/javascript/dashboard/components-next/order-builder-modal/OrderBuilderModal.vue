<script setup>
import {
  ref,
  computed,
  shallowRef,
  onMounted,
  onUnmounted,
  nextTick,
} from 'vue';
import { useI18n } from 'vue-i18n';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';
import Icon from 'next/icon/Icon.vue';
import CaptainErpProxy from 'dashboard/api/captain/erpProxy';
import StepIndicator from './StepIndicator.vue';
import ProductCatalogGrid from './ProductCatalogGrid.vue';
import DeliveryAddressStep from './DeliveryAddressStep.vue';
import ReviewStep from './ReviewStep.vue';
import CartSidebar from './CartSidebar.vue';
import ConfirmDiscardDialog from './ConfirmDiscardDialog.vue';
import { formatPrice } from './formatPrice';

const props = defineProps({
  assistantId: { type: Number, required: true },
  lineUserId: { type: String, default: '' },
  contactName: { type: String, default: '' },
  initialState: { type: Object, default: null },
});

const emit = defineEmits(['close', 'discard', 'send']);

const { t } = useI18n();
const I18N = 'CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL';

// State
const isVisible = ref(false);
const catalogRef = ref(null);
const currentStep = ref(1);
const completedSteps = ref([]);

// Cart state
const cartItems = ref([]);
const recentlyAdded = shallowRef(new Map());
const highlightedItem = ref('');
const liveMessage = ref('');

// Delivery state
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
  notes: '',
});
const registerCustomer = ref(false);
let lookupController = null;

// Send state
const sendState = ref('idle');
const sendError = ref('');
let autoCloseTimer = null;

// Close confirmation
const showConfirmDialog = ref(false);

// Step transition direction
const stepDirection = ref('forward');

// Computed
const cartItemCount = computed(() =>
  cartItems.value.reduce((sum, i) => sum + i.qty, 0)
);

const isAddressValid = computed(() => {
  if (selectedAddress.value !== null) return true;
  const f = addressForm.value;
  return !!(
    f.name?.trim() &&
    f.phone?.trim() &&
    f.address_line1?.trim() &&
    f.city?.trim() &&
    f.state?.trim() &&
    f.pincode?.trim()
  );
});

const cartActionLabel = computed(() => {
  if (currentStep.value === 1) return t(`${I18N}.NEXT_DELIVERY`);
  if (currentStep.value === 2) return t(`${I18N}.NEXT_REVIEW`);
  return '';
});

const cartActionDisabled = computed(() => {
  if (currentStep.value === 1) return cartItems.value.length === 0;
  if (currentStep.value === 2) return !isAddressValid.value;
  return true;
});

const grandTotalFormatted = computed(() => {
  const total = cartItems.value.reduce((s, i) => s + (i.price || 0) * i.qty, 0);
  const curr = cartItems.value[0]?.currency || 'THB';
  return formatPrice(total, curr);
});

const recipientName = computed(() => {
  return (
    addressForm.value.name ||
    customerData.value?.display_name ||
    props.contactName ||
    ''
  );
});

const resolvedAddress = computed(() => {
  if (selectedAddress.value && customerData.value?.addresses) {
    return customerData.value.addresses.find(
      a => a.name === selectedAddress.value
    );
  }
  return null;
});

// Cart methods
function addToCart(product) {
  const existing = cartItems.value.find(
    item => item.item_code === product.item_code
  );
  if (existing) {
    existing.qty += 1;
    highlightedItem.value = product.item_code;
    setTimeout(() => {
      if (highlightedItem.value === product.item_code) {
        highlightedItem.value = '';
      }
    }, 600);
  } else {
    cartItems.value.push({
      item_code: product.item_code,
      item_name: product.item_name,
      price: product.price,
      currency: product.currency || 'THB',
      image_url: product.image_url || product.image || null,
      qty: 1,
    });
  }
  liveMessage.value = t(`${I18N}.ADDED_ANNOUNCEMENT`, {
    name: product.item_name,
  });

  const map = new Map(recentlyAdded.value);
  const prevTimeout = map.get(product.item_code);
  if (prevTimeout) clearTimeout(prevTimeout);
  const timeoutId = setTimeout(() => {
    const updated = new Map(recentlyAdded.value);
    updated.delete(product.item_code);
    recentlyAdded.value = updated;
  }, 600);
  map.set(product.item_code, timeoutId);
  recentlyAdded.value = map;
}

function removeFromCart(itemCode) {
  const item = cartItems.value.find(i => i.item_code === itemCode);
  const itemName = item?.item_name || 'Item';
  cartItems.value = cartItems.value.filter(i => i.item_code !== itemCode);
  liveMessage.value = t(`${I18N}.REMOVED_ANNOUNCEMENT`, { name: itemName });

  const prevTimeout = recentlyAdded.value.get(itemCode);
  if (prevTimeout) {
    clearTimeout(prevTimeout);
    const updated = new Map(recentlyAdded.value);
    updated.delete(itemCode);
    recentlyAdded.value = updated;
  }
}

function updateQty(itemCode, newQty) {
  const parsed = parseInt(newQty, 10);
  if (Number.isNaN(parsed) || parsed < 1) {
    removeFromCart(itemCode);
    return;
  }
  const item = cartItems.value.find(i => i.item_code === itemCode);
  if (item) {
    item.qty = parsed;
  }
}

function incrementQty(itemCode) {
  const item = cartItems.value.find(i => i.item_code === itemCode);
  if (item) {
    item.qty += 1;
  }
}

function decrementQty(itemCode) {
  const item = cartItems.value.find(i => i.item_code === itemCode);
  if (!item) return;
  if (item.qty <= 1) {
    removeFromCart(itemCode);
  } else {
    item.qty -= 1;
  }
}

// Step navigation
function onNextStep() {
  if (!completedSteps.value.includes(1)) {
    completedSteps.value.push(1);
  }
  stepDirection.value = 'forward';
  currentStep.value = 2;
}

function onNextReview() {
  if (!completedSteps.value.includes(2)) {
    completedSteps.value.push(2);
  }
  stepDirection.value = 'forward';
  currentStep.value = 3;
}

function onCartNext() {
  if (currentStep.value === 1) onNextStep();
  else if (currentStep.value === 2) onNextReview();
}

function onStepClick(stepId) {
  stepDirection.value = stepId < currentStep.value ? 'back' : 'forward';
  currentStep.value = stepId;
}

function onBackToProducts() {
  stepDirection.value = 'back';
  currentStep.value = 1;
}

function onBackToDelivery() {
  stepDirection.value = 'back';
  currentStep.value = 2;
}

// Customer lookup for delivery
async function lookupLineCustomer() {
  lookupController = new AbortController();
  const timeout = setTimeout(() => lookupController?.abort(), 3000);
  try {
    const { data } = await CaptainErpProxy.lookupLineCustomer({
      assistantId: props.assistantId,
      lineUserId: props.lineUserId,
      signal: lookupController.signal,
    });
    clearTimeout(timeout);
    customerData.value = data;
    if (data.is_member && data.addresses?.length > 0) {
      deliveryState.value = 'member';
      const defaultAddr = data.addresses.find(a => a.is_shipping_address);
      selectedAddress.value =
        defaultAddr?.name || data.addresses[0]?.name || null;
    } else {
      deliveryState.value = 'new_customer';
      addressForm.value.name = data.display_name || props.contactName || '';
    }
  } catch {
    clearTimeout(timeout);
    deliveryState.value = props.lineUserId ? 'new_customer' : 'no_line';
    addressForm.value.name = props.contactName || '';
  }
}

function resetAndClose() {
  if (autoCloseTimer) {
    clearTimeout(autoCloseTimer);
    autoCloseTimer = null;
  }
  // Reset all state for clean next open
  cartItems.value = [];
  currentStep.value = 1;
  completedSteps.value = [];
  sendState.value = 'idle';
  sendError.value = '';
  selectedAddress.value = null;
  addressForm.value = {
    name: '',
    phone: '',
    address_line1: '',
    city: '',
    state: '',
    pincode: '',
    notes: '',
  };
  registerCustomer.value = false;
  showConfirmDialog.value = false;
  // Trigger close animation then unmount via parent (discard = delete saved state)
  isVisible.value = false;
  setTimeout(() => emit('discard'), 200);
}

// Send checkout link
async function handleSendCheckout() {
  if (sendState.value === 'sending') return;
  sendState.value = 'sending';
  sendError.value = '';
  try {
    const payload = {
      assistantId: props.assistantId,
      items: cartItems.value.map(i => ({
        item_code: i.item_code,
        qty: i.qty,
        rate: i.price || 0,
      })),
      lineUserId: props.lineUserId || undefined,
      registerCustomer: registerCustomer.value || undefined,
    };
    if (selectedAddress.value) {
      payload.addressName = selectedAddress.value;
    } else {
      payload.addressData = { ...addressForm.value };
    }
    if (customerData.value?.customer_email) {
      payload.customerEmail = customerData.value.customer_email;
    }
    const { data } = await CaptainErpProxy.createSharedCheckout(payload);
    const result = data?.data || data;
    const url = result.url || result.checkout_url;
    const total = result.grand_total;

    sendState.value = 'success';
    liveMessage.value = t(`${I18N}.SEND_SUCCESS`);

    // Format message for conversation — intentionally not i18n'd
    // (sent to customer in chat; multi-language handled server-side if needed)
    const curr = cartItems.value[0]?.currency || 'THB';
    const formattedTotal = formatPrice(total, curr);
    const message = `Your order is ready! Total: ${formattedTotal}\n${url}`;
    emit('send', message);

    autoCloseTimer = setTimeout(() => {
      resetAndClose();
    }, 2000);
  } catch (err) {
    sendState.value = 'error';
    sendError.value =
      err.response?.data?.message ||
      err.response?.data?.error ||
      'Something went wrong';
  }
}

// Close — save state if cart has items, just close if empty
function requestClose() {
  isVisible.value = false;
  setTimeout(() => emit('close'), 200);
}

function onConfirmDiscard() {
  showConfirmDialog.value = false;
  resetAndClose();
}

function onKeepEditing() {
  showConfirmDialog.value = false;
}

// Escape key handler
function onKeydown(e) {
  if (e.key === 'Escape') {
    if (showConfirmDialog.value) return; // dialog handles its own Escape
    requestClose();
  }
}

// State snapshot for per-conversation persistence
function getState() {
  return {
    cartItems: JSON.parse(JSON.stringify(cartItems.value)),
    currentStep: currentStep.value,
    completedSteps: [...completedSteps.value],
    deliveryState: deliveryState.value,
    customerData: customerData.value
      ? JSON.parse(JSON.stringify(customerData.value))
      : null,
    selectedAddress: selectedAddress.value,
    addressForm: { ...addressForm.value },
    registerCustomer: registerCustomer.value,
  };
}

function restoreState(saved) {
  if (!saved) return;
  cartItems.value = saved.cartItems || [];
  currentStep.value = saved.currentStep || 1;
  completedSteps.value = saved.completedSteps || [];
  deliveryState.value = saved.deliveryState || 'loading';
  customerData.value = saved.customerData || null;
  selectedAddress.value = saved.selectedAddress || null;
  addressForm.value = saved.addressForm || {
    name: '',
    phone: '',
    address_line1: '',
    city: '',
    state: '',
    pincode: '',
    notes: '',
  };
  registerCustomer.value = saved.registerCustomer || false;
}

defineExpose({ getState, restoreState });

// Lifecycle
onMounted(() => {
  nextTick(() => {
    isVisible.value = true;
    setTimeout(() => {
      catalogRef.value?.focusSearch();
    }, 250);
  });
  document.addEventListener('keydown', onKeydown);
  if (props.initialState) {
    restoreState(props.initialState);
  } else if (props.lineUserId) {
    lookupLineCustomer();
  } else {
    deliveryState.value = 'no_line';
    addressForm.value.name = props.contactName || '';
  }
});

onUnmounted(() => {
  document.removeEventListener('keydown', onKeydown);
  if (lookupController) lookupController.abort();
  if (autoCloseTimer) clearTimeout(autoCloseTimer);
  // Clear all pending checkmark animation timers
  recentlyAdded.value.forEach(timeoutId => clearTimeout(timeoutId));
  recentlyAdded.value = new Map();
});

// Backdrop click
function onBackdropClick(e) {
  if (e.target === e.currentTarget) {
    requestClose();
  }
}
</script>

<template>
  <TeleportWithDirection to="body">
    <!-- Backdrop + Modal -->
    <Transition
      enter-active-class="transition-opacity duration-200 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-opacity duration-150 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="isVisible"
        class="fixed inset-0 z-[9999] flex items-center justify-center bg-n-alpha-black1 backdrop-blur-[4px]"
        role="dialog"
        :aria-label="t(`${I18N}.TITLE`)"
        aria-modal="true"
        @click="onBackdropClick"
      >
        <!-- Modal container -->
        <Transition
          enter-active-class="transition-transform duration-200 ease-out"
          enter-from-class="translate-y-full"
          enter-to-class="translate-y-0"
          leave-active-class="transition-transform duration-150 ease-in"
          leave-from-class="translate-y-0"
          leave-to-class="translate-y-full"
          appear
        >
          <div
            class="relative flex h-[90vh] w-[95vw] max-w-[1400px] flex-col overflow-hidden rounded-xl bg-n-solid-1 shadow-xl"
            @click.stop
          >
            <!-- Header bar -->
            <div
              class="flex shrink-0 items-center justify-between border-b border-n-weak px-4 py-3"
            >
              <h2 class="text-base font-semibold text-n-slate-12">
                {{ t(`${I18N}.TITLE`) }}
              </h2>
              <button
                class="flex h-8 w-8 items-center justify-center rounded-lg text-n-slate-11 transition-colors hover:bg-n-slate-3 hover:text-n-slate-12"
                :aria-label="t(`${I18N}.CLOSE`)"
                @click="requestClose"
              >
                <Icon icon="i-lucide-x" size="18" />
              </button>
            </div>

            <!-- Two-column layout -->
            <div class="flex min-h-0 flex-1">
              <!-- Left panel (60%) — Step indicator + content -->
              <div class="flex w-3/5 flex-col overflow-hidden">
                <StepIndicator
                  :current-step="currentStep"
                  :completed-steps="completedSteps"
                  :cart-item-count="cartItemCount"
                  @step-click="onStepClick"
                />
                <Transition
                  :name="
                    stepDirection === 'forward' ? 'slide-left' : 'slide-right'
                  "
                  mode="out-in"
                >
                  <ProductCatalogGrid
                    v-if="currentStep === 1"
                    :key="1"
                    ref="catalogRef"
                    :assistant-id="assistantId"
                    :recently-added="recentlyAdded"
                    class="min-h-0 flex-1"
                    @add-product="addToCart"
                  />
                  <DeliveryAddressStep
                    v-else-if="currentStep === 2"
                    :key="2"
                    :assistant-id="assistantId"
                    :delivery-state="deliveryState"
                    :customer-data="customerData"
                    :selected-address="selectedAddress"
                    :address-form="addressForm"
                    :register-customer="registerCustomer"
                    class="min-h-0 flex-1 overflow-y-auto"
                    @select-address="selectedAddress = $event"
                    @update:address-form="addressForm = $event"
                    @update:register-customer="registerCustomer = $event"
                    @back="onBackToProducts"
                  />
                  <ReviewStep
                    v-else-if="currentStep === 3"
                    :key="3"
                    :items="cartItems"
                    :resolved-address="resolvedAddress"
                    :address-form="addressForm"
                    :grand-total="grandTotalFormatted"
                    :send-state="sendState"
                    :send-error="sendError"
                    class="min-h-0 flex-1 overflow-y-auto"
                    @send="handleSendCheckout"
                    @back="onBackToDelivery"
                  />
                </Transition>
              </div>

              <!-- Right panel (40%) — Cart sidebar -->
              <CartSidebar
                :items="cartItems"
                :highlighted-item="highlightedItem"
                :action-label="cartActionLabel"
                :action-disabled="cartActionDisabled"
                class="w-2/5"
                @next="onCartNext"
                @increment="incrementQty"
                @decrement="decrementQty"
                @update-qty="updateQty"
                @remove="removeFromCart"
              />
            </div>

            <!-- Sending overlay -->
            <Transition
              enter-active-class="transition-opacity duration-200 ease-out"
              enter-from-class="opacity-0"
              enter-to-class="opacity-100"
              leave-active-class="transition-opacity duration-150 ease-in"
              leave-from-class="opacity-100"
              leave-to-class="opacity-0"
            >
              <div
                v-if="sendState === 'sending' || sendState === 'success'"
                class="absolute inset-0 z-10 flex flex-col items-center justify-center gap-4 rounded-xl bg-n-solid-1/95 backdrop-blur-sm"
              >
                <template v-if="sendState === 'sending'">
                  <div
                    class="flex h-14 w-14 items-center justify-center rounded-full bg-n-blue-3"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      width="28"
                      height="28"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      class="animate-spin text-n-blue-11"
                    >
                      <path d="M21 12a9 9 0 1 1-6.219-8.56" />
                    </svg>
                  </div>
                  <div class="flex flex-col items-center gap-1">
                    <p class="text-base font-semibold text-n-slate-12">
                      {{ t(`${I18N}.SENDING_OVERLAY_TITLE`) }}
                    </p>
                    <p v-if="recipientName" class="text-sm text-n-slate-10">
                      {{
                        t(`${I18N}.SENDING_OVERLAY_SUBTITLE`, {
                          name: recipientName,
                        })
                      }}
                    </p>
                  </div>
                </template>
                <template v-else>
                  <div
                    class="flex h-14 w-14 items-center justify-center rounded-full bg-n-green-3"
                  >
                    <Icon
                      icon="i-lucide-check"
                      size="28"
                      class="text-n-green-11"
                    />
                  </div>
                  <p class="text-base font-semibold text-n-slate-12">
                    {{ t(`${I18N}.SEND_SUCCESS`) }}
                  </p>
                </template>
              </div>
            </Transition>

            <!-- Screen reader announcements -->
            <div aria-live="polite" class="sr-only">
              {{ liveMessage }}
            </div>
          </div>
        </Transition>
      </div>
    </Transition>

    <!-- Close confirmation dialog -->
    <ConfirmDiscardDialog
      :show="showConfirmDialog"
      @discard="onConfirmDiscard"
      @keep-editing="onKeepEditing"
    />
  </TeleportWithDirection>
</template>

<style scoped>
.slide-left-enter-active,
.slide-left-leave-active,
.slide-right-enter-active,
.slide-right-leave-active {
  transition:
    transform 200ms ease-in-out,
    opacity 200ms ease-in-out;
}
.slide-left-enter-from {
  transform: translateX(30px);
  opacity: 0;
}
.slide-left-leave-to {
  transform: translateX(-30px);
  opacity: 0;
}
.slide-right-enter-from {
  transform: translateX(-30px);
  opacity: 0;
}
.slide-right-leave-to {
  transform: translateX(30px);
  opacity: 0;
}
</style>
