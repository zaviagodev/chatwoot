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
  return '฿' + amount.toLocaleString('en-US');
});

const hasLastOrder = computed(() => !!customAttrs.value.erp_last_order_date);

const lastOrderDate = computed(() => {
  const dateStr = customAttrs.value.erp_last_order_date;
  if (!dateStr) return '';
  try {
    const date = parseISO(dateStr);
    return isThisYear(date) ? format(date, 'd MMM') : format(date, 'MMM yyyy');
  } catch {
    return '';
  }
});

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

const statsText = computed(() => {
  const orders = t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.ORDERS_LABEL');
  const parts = [`${totalOrders.value} ${orders}`, totalRevenue.value];
  if (hasLastOrder.value) {
    const last = t('CONVERSATION_SIDEBAR.ERP_CUSTOMER_CARD.LAST_ORDER', {
      date: lastOrderDate.value,
    });
    parts.push(last);
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
      </div>

      <!-- Expanded details -->
      <div
        class="overflow-hidden transition-all duration-150"
        :class="isExpanded ? 'max-h-24 mt-2' : 'max-h-0'"
      >
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
