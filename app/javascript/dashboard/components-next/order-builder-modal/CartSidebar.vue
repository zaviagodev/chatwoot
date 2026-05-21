<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'next/icon/Icon.vue';
import CartItemRow from './CartItemRow.vue';

const props = defineProps({
  items: { type: Array, default: () => [] },
  highlightedItem: { type: String, default: '' },
  actionLabel: { type: String, default: '' },
  actionDisabled: { type: Boolean, default: false },
});

defineEmits(['next', 'increment', 'decrement', 'updateQty', 'remove']);

const { t } = useI18n();
const I18N = 'CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL';

const formattedSubtotal = computed(() => {
  if (props.items.length === 0) return '';
  if (props.items.some(item => item.price == null)) {
    return t(`${I18N}.ESTIMATED_TOTAL_UNAVAILABLE`);
  }
  const total = props.items.reduce(
    (sum, item) => sum + (item.price + (item.addon_total || 0)) * item.qty,
    0
  );
  const curr = props.items[0]?.currency || 'THB';
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
});
</script>

<template>
  <aside class="flex h-full flex-col border-l border-n-weak bg-n-slate-1">
    <!-- Header -->
    <div class="border-b border-n-weak px-4 py-3">
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ t(`${I18N}.ORDER_SUMMARY`) }}
      </h3>
    </div>

    <!-- Cart content area -->
    <div class="flex min-h-0 flex-1 flex-col">
      <!-- Empty cart state -->
      <div
        v-if="items.length === 0"
        class="flex flex-1 flex-col items-center justify-center p-6"
      >
        <div class="flex flex-col items-center gap-3 text-center">
          <div
            class="flex h-16 w-16 items-center justify-center rounded-full bg-n-slate-3"
          >
            <Icon
              icon="i-lucide-shopping-bag"
              size="28"
              class="text-n-slate-9"
            />
          </div>
          <p class="text-sm text-n-slate-11">
            {{ t(`${I18N}.EMPTY_CART`) }}
          </p>
        </div>
      </div>

      <!-- Cart items list -->
      <div v-else class="min-h-0 flex-1 overflow-y-auto">
        <TransitionGroup
          tag="div"
          enter-active-class="transition-all duration-150 ease-out"
          enter-from-class="translate-x-4 opacity-0"
          enter-to-class="translate-x-0 opacity-100"
          leave-active-class="transition-all duration-150 ease-in"
          leave-from-class="translate-x-0 opacity-100"
          leave-to-class="translate-x-4 opacity-0"
        >
          <CartItemRow
            v-for="item in items"
            :key="item.item_code"
            :item="item"
            :highlighted="highlightedItem === item.item_code"
            @increment="$emit('increment', item.item_code)"
            @decrement="$emit('decrement', item.item_code)"
            @update-qty="$emit('updateQty', item.item_code, $event)"
            @remove="$emit('remove', item.item_code)"
          />
        </TransitionGroup>
      </div>
    </div>

    <!-- Subtotal -->
    <div v-if="items.length > 0" class="border-t border-n-weak px-4 py-3">
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium text-n-slate-11">
          {{ t(`${I18N}.SUBTOTAL`) }}
        </span>
        <span class="text-sm font-semibold text-n-slate-12">
          {{ formattedSubtotal }}
        </span>
      </div>
      <p class="mt-1 text-xs text-n-slate-9">
        {{ t(`${I18N}.ESTIMATED_TOTAL`) }}
      </p>
    </div>

    <!-- Footer with action button -->
    <div v-if="actionLabel" class="border-t border-n-weak p-4">
      <button
        class="flex w-full items-center justify-center rounded-lg px-4 py-2.5 text-sm font-semibold transition-colors"
        :class="
          !actionDisabled
            ? 'bg-n-blue-9 text-white hover:bg-n-blue-10'
            : 'cursor-not-allowed bg-n-slate-3 text-n-slate-9'
        "
        :disabled="actionDisabled"
        @click="$emit('next')"
      >
        {{ actionLabel }}
      </button>
    </div>
  </aside>
</template>
