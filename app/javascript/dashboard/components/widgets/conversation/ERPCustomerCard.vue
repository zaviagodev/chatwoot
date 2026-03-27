<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { format, parseISO, isThisYear } from 'date-fns';

const props = defineProps({
  contact: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();

const isExpanded = ref(false);

const customAttrs = computed(() => props.contact?.custom_attributes || {});

const isKnownCustomer = computed(() => !!customAttrs.value.erp_customer_id);

const customerName = computed(
  () => customAttrs.value.erp_customer_name || customAttrs.value.erp_customer_id
);

const totalOrders = computed(() => customAttrs.value.erp_total_orders || 0);

const totalRevenue = computed(() => {
  const amount = Math.round(customAttrs.value.erp_total_revenue || 0);
  return '\u0E3F' + amount.toLocaleString('en-US');
});

const hasLastOrder = computed(() => !!customAttrs.value.erp_last_order_date);

const formatDate = dateStr => {
  if (!dateStr) return '';
  try {
    const date = parseISO(dateStr);
    return isThisYear(date) ? format(date, 'd MMM') : format(date, 'MMM yyyy');
  } catch {
    return '';
  }
};

const lastOrderDate = computed(() =>
  formatDate(customAttrs.value.erp_last_order_date)
);

const memberSince = computed(() => {
  const dateStr = customAttrs.value.erp_member_since;
  if (!dateStr) return '';
  try {
    const date = parseISO(dateStr);
    return format(date, 'MMM yyyy');
  } catch {
    return '';
  }
});

const addressCount = computed(() => customAttrs.value.erp_address_count || 0);

// --- New computed properties (Plan 127 Epic 02) ---

const customerGroup = computed(() => {
  const group = customAttrs.value.erp_customer_group;
  if (!group || group === 'All Customer Groups') return null;
  return group;
});

const avgOrderValue = computed(() => {
  const val = customAttrs.value.erp_avg_order_value;
  if (!val || val <= 0) return null;
  return '\u0E3F' + Math.round(val).toLocaleString('en-US');
});

const hasCart = computed(() => (customAttrs.value.erp_cart_items || 0) > 0);
const cartItems = computed(() => customAttrs.value.erp_cart_items || 0);
const cartTotal = computed(() => {
  const val = Math.round(customAttrs.value.erp_cart_total || 0);
  return '\u0E3F' + val.toLocaleString('en-US');
});

const parseOrderString = str => {
  if (!str) return null;
  const parts = str.split('|');
  if (parts.length < 3) return null;
  return {
    dateFormatted: formatDate(parts[0]),
    totalFormatted:
      '\u0E3F' + Math.round(Number(parts[1]) || 0).toLocaleString('en-US'),
    status: parts[2],
    items: parts.slice(3).join('|') || '',
  };
};

const recentOrders = computed(() =>
  ['erp_recent_order_1', 'erp_recent_order_2', 'erp_recent_order_3']
    .map(key => parseOrderString(customAttrs.value[key]))
    .filter(Boolean)
);

const outstandingBalance = computed(() => {
  const val = customAttrs.value.erp_outstanding;
  if (!val || val <= 0) return null;
  return val;
});

const outstandingFormatted = computed(() => {
  if (!outstandingBalance.value) return '';
  return (
    '\u0E3F' + Math.round(outstandingBalance.value).toLocaleString('en-US')
  );
});

const STATUS_I18N_MAP = {
  Completed: 'ORDER_STATUS_COMPLETED',
  'To Deliver': 'ORDER_STATUS_TO_DELIVER',
  'To Bill': 'ORDER_STATUS_TO_BILL',
  Cancelled: 'ORDER_STATUS_CANCELLED',
};

const statusLabel = status => {
  const key = STATUS_I18N_MAP[status];
  return key ? t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.' + key) : status;
};

const statusBadgeClass = status => {
  switch (status) {
    case 'Completed':
      return 'bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-400';
    case 'To Deliver':
    case 'To Bill':
      return 'bg-blue-50 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400';
    case 'Cancelled':
      return 'bg-red-50 text-red-700 dark:bg-red-900/30 dark:text-red-400';
    default:
      return 'bg-n-alpha-1 text-n-slate-11';
  }
};

// --- Stats text (updated to include avg order value) ---

const statsText = computed(() => {
  const orders = t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.ORDERS_LABEL');
  const parts = [`${totalOrders.value} ${orders}`, totalRevenue.value];
  if (avgOrderValue.value) {
    parts.push(
      t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.AVG_ORDER', {
        amount: avgOrderValue.value,
      })
    );
  }
  if (hasLastOrder.value) {
    parts.push(
      t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.LAST_ORDER', {
        date: lastOrderDate.value,
      })
    );
  }
  return parts.join(' \u00B7 ');
});

const hasChannelMismatch = computed(
  () => customAttrs.value.erp_line_channel_match === false
);

const toggleExpand = () => {
  isExpanded.value = !isExpanded.value;
};

const handleKeydown = event => {
  if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault();
    toggleExpand();
  }
};
</script>

<template>
  <div class="px-4 py-3 border-b border-n-weak">
    <!-- Known customer state -->
    <div v-if="isKnownCustomer">
      <div
        role="button"
        tabindex="0"
        class="cursor-pointer select-none"
        @click="toggleExpand"
        @keydown="handleKeydown"
      >
        <!-- Badge row -->
        <div class="flex items-center justify-between mb-1">
          <div class="flex items-center gap-1.5">
            <span
              class="inline-block w-2 h-2 bg-green-500 rounded-full flex-shrink-0"
              :aria-label="
                $t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.CUSTOMER')
              "
            />
            <span class="text-sm font-medium text-n-slate-12">
              {{ $t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.CUSTOMER') }}
            </span>
            <span
              v-if="customerGroup"
              class="text-[10px] font-medium px-1.5 py-0.5 rounded-full bg-n-alpha-1 text-n-slate-11"
            >
              {{ customerGroup }}
            </span>
          </div>
          <div class="flex items-center gap-1">
            <span
              v-if="hasChannelMismatch"
              v-tooltip="
                $t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.CHANNEL_MISMATCH')
              "
              class="i-lucide-alert-triangle size-3.5 text-amber-500"
              :aria-label="
                $t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.CHANNEL_MISMATCH')
              "
            />
            <span
              class="i-lucide-chevron-right size-3.5 text-n-slate-9 transition-transform duration-150"
              :class="{ 'rotate-90': isExpanded }"
            />
          </div>
        </div>

        <!-- Customer name -->
        <div
          class="text-sm font-medium text-n-slate-12 truncate mb-0.5"
          :title="customerName"
        >
          {{ customerName }}
        </div>

        <!-- Stats row -->
        <div class="text-xs text-n-slate-11">
          {{ statsText }}
        </div>

        <!-- Cart line -->
        <div
          v-if="hasCart"
          class="flex items-center gap-1 text-xs text-amber-600 dark:text-amber-400 mt-0.5"
        >
          <span class="i-lucide-shopping-cart size-3" />
          <span>{{
            cartItems === 1
              ? $t(
                  'CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.CART_ITEM_SINGULAR',
                  { amount: cartTotal }
                )
              : $t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.CART_SUMMARY', {
                  count: cartItems,
                  amount: cartTotal,
                })
          }}</span>
        </div>
      </div>

      <!-- Expanded details -->
      <div
        class="overflow-hidden transition-all duration-150"
        :class="isExpanded ? 'max-h-80 mt-2' : 'max-h-0'"
      >
        <!-- Recent Orders section -->
        <div v-if="recentOrders.length" class="mb-2">
          <div
            class="text-[10px] font-semibold text-n-slate-9 uppercase tracking-wider mb-1"
          >
            {{ $t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.RECENT_ORDERS') }}
          </div>
          <div v-for="(order, idx) in recentOrders" :key="idx" class="mb-1.5">
            <div class="flex items-center justify-between text-xs">
              <span class="text-n-slate-11">{{ order.dateFormatted }}</span>
              <div class="flex items-center gap-1.5">
                <span class="text-n-slate-12">{{ order.totalFormatted }}</span>
                <span
                  :class="statusBadgeClass(order.status)"
                  class="text-[10px] px-1.5 py-0.5 rounded-full font-medium"
                >
                  {{ statusLabel(order.status) }}
                </span>
              </div>
            </div>
            <div v-if="order.items" class="text-[11px] text-n-slate-9 truncate">
              {{ order.items }}
            </div>
          </div>
        </div>

        <!-- Details section -->
        <div>
          <div
            class="text-[10px] font-semibold text-n-slate-9 uppercase tracking-wider mb-1"
          >
            {{ $t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.DETAILS') }}
          </div>
          <div class="text-xs text-n-slate-11 space-y-1">
            <div v-if="memberSince" class="flex justify-between">
              <span>{{
                $t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.MEMBER_SINCE')
              }}</span>
              <span class="text-n-slate-12">{{ memberSince }}</span>
            </div>
            <div class="flex justify-between">
              <span>{{
                $t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.ADDRESSES', {
                  count: addressCount,
                })
              }}</span>
            </div>
            <div v-if="outstandingBalance" class="flex justify-between">
              <span>{{
                $t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.OUTSTANDING')
              }}</span>
              <span class="text-amber-600 dark:text-amber-400">{{
                outstandingFormatted
              }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Empty state: LINE contact not linked to ERP -->
    <div
      v-else
      class="flex items-center gap-1.5"
      :aria-label="$t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.NOT_LINKED')"
    >
      <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
      <span class="text-n-slate-9">&mdash;</span>
      <span class="text-xs text-n-slate-9">
        {{ $t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.NOT_LINKED') }}
      </span>
    </div>
  </div>
</template>
