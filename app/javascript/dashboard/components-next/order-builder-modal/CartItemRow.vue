<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  item: { type: Object, required: true },
  highlighted: { type: Boolean, default: false },
});

const emit = defineEmits(['increment', 'decrement', 'updateQty', 'remove']);

const { t } = useI18n();
const I18N = 'CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL';

const imageError = ref(false);
const justChanged = ref(false);

const imageUrl = computed(() => props.item.image_url || props.item.image || '');

const formattedLineTotal = computed(() => {
  const { price, currency, qty } = props.item;
  if (!price && price !== 0) return '';
  const addonTotal = props.item.addon_total || 0;
  const total = (price + addonTotal) * qty;
  const curr = currency || 'THB';
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

const isAtMinQty = computed(() => props.item.qty <= 1);

// Qty bounce animation
watch(
  () => props.item.qty,
  () => {
    justChanged.value = true;
    setTimeout(() => {
      justChanged.value = false;
    }, 100);
  }
);

function onQtyInput(event) {
  const parsed = parseInt(event.target.value, 10);
  if (!Number.isNaN(parsed) && parsed >= 1) {
    emit('updateQty', parsed);
  }
}

function onQtyBlur(event) {
  const parsed = parseInt(event.target.value, 10);
  if (Number.isNaN(parsed) || parsed < 1) {
    // Reset to 1 on blur — never remove via blur
    event.target.value = '1';
    emit('updateQty', 1);
  }
}

function onMinusClick() {
  if (isAtMinQty.value) {
    emit('remove');
  } else {
    emit('decrement');
  }
}
</script>

<template>
  <div
    class="flex items-center gap-3 px-4 py-2 transition-colors"
    :class="{ 'animate-pulse bg-n-blue-3': highlighted }"
  >
    <!-- Thumbnail -->
    <div class="h-10 w-10 shrink-0 overflow-hidden rounded-lg bg-n-slate-3">
      <img
        v-if="imageUrl && !imageError"
        :src="imageUrl"
        :alt="item.item_name"
        class="h-full w-full object-cover"
        loading="lazy"
        @error="imageError = true"
      />
      <div
        v-else
        class="flex h-full w-full items-center justify-center text-n-slate-9"
      >
        <Icon icon="i-lucide-package" size="16" />
      </div>
    </div>

    <!-- Name + line total -->
    <div class="min-w-0 flex-1">
      <p
        class="line-clamp-2 text-sm font-medium leading-tight text-n-slate-12"
        :title="item.item_name"
      >
        {{ item.item_name }}
      </p>
      <p
        v-if="item.bundle_children_summary || item.customization_summary"
        class="truncate text-xs text-n-slate-9"
        :title="
          [item.bundle_children_summary, item.customization_summary]
            .filter(Boolean)
            .join(' · ')
        "
      >
        {{
          [item.bundle_children_summary, item.customization_summary]
            .filter(Boolean)
            .join(' · ')
        }}
      </p>
      <p class="text-xs text-n-slate-11">
        {{ formattedLineTotal }}
      </p>
    </div>

    <!-- Quantity stepper -->
    <div class="flex shrink-0 items-center gap-1">
      <!-- Minus / Trash button -->
      <button
        class="flex h-7 w-7 items-center justify-center rounded-md transition-colors"
        :class="
          isAtMinQty
            ? 'text-n-ruby-11 hover:bg-n-ruby-3'
            : 'text-n-slate-11 hover:bg-n-slate-3'
        "
        :aria-label="
          isAtMinQty
            ? t(`${I18N}.REMOVE_ITEM`, { name: item.item_name })
            : t(`${I18N}.DECREASE_QTY`)
        "
        @click="onMinusClick"
      >
        <Icon
          :icon="isAtMinQty ? 'i-lucide-trash-2' : 'i-lucide-minus'"
          size="14"
        />
      </button>

      <!-- Editable quantity input -->
      <input
        type="text"
        inputmode="numeric"
        :value="item.qty"
        class="!h-7 !w-10 rounded-md border border-n-weak bg-n-slate-2 text-center !text-sm text-n-slate-12 transition-transform focus:border-n-blue-9 focus:outline-none focus:ring-1 focus:ring-n-blue-9"
        :class="{ 'scale-110': justChanged }"
        :aria-label="t(`${I18N}.ITEMS_COUNT_SINGULAR`, { count: item.qty })"
        @input="onQtyInput"
        @blur="onQtyBlur"
      />

      <!-- Plus button -->
      <button
        class="flex h-7 w-7 items-center justify-center rounded-md text-n-slate-11 transition-colors hover:bg-n-slate-3"
        :aria-label="t(`${I18N}.INCREASE_QTY`)"
        @click="$emit('increment')"
      >
        <Icon icon="i-lucide-plus" size="14" />
      </button>
    </div>
  </div>
</template>
