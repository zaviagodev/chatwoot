<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  product: { type: Object, required: true },
  justAdded: { type: Boolean, default: false },
});

defineEmits(['add']);

const { t } = useI18n();
const imageError = ref(false);

const isOutOfStock = computed(
  () => props.product.stock_status === 'out_of_stock'
);

const formattedPrice = computed(() => {
  const { price, currency } = props.product;
  if (!price && price !== 0) {
    return t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.PRICE_UNAVAILABLE');
  }
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

const stockLabel = computed(() =>
  isOutOfStock.value
    ? t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.OUT_OF_STOCK')
    : t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.IN_STOCK')
);

const imageUrl = computed(
  () => props.product.image_url || props.product.image || ''
);

const ariaLabel = computed(() =>
  t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.PRODUCT_ARIA', {
    name: props.product.item_name,
    price: formattedPrice.value,
    stock: stockLabel.value,
  })
);
</script>

<template>
  <div
    class="flex flex-col overflow-hidden rounded-lg border border-n-weak bg-n-slate-2 transition-all duration-150 hover:-translate-y-0.5 hover:shadow-md"
    :aria-label="ariaLabel"
  >
    <!-- Product image -->
    <div class="relative aspect-square w-full overflow-hidden bg-n-slate-3">
      <img
        v-if="imageUrl && !imageError"
        :src="imageUrl"
        :alt="product.item_name"
        class="h-full w-full object-cover"
        loading="lazy"
        @error="imageError = true"
      />
      <div
        v-else
        class="flex h-full w-full flex-col items-center justify-center gap-1 text-n-slate-9"
      >
        <Icon icon="i-lucide-package" size="48" />
      </div>
      <!-- Add-to-cart checkmark overlay -->
      <Transition
        enter-active-class="transition-opacity duration-300"
        enter-from-class="opacity-0"
        enter-to-class="opacity-100"
        leave-active-class="transition-opacity duration-300"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0"
      >
        <div
          v-if="justAdded"
          class="absolute inset-0 z-10 flex items-center justify-center rounded-none bg-green-600/80"
        >
          <Icon icon="i-lucide-check" size="32" class="text-white" />
        </div>
      </Transition>
    </div>

    <!-- Product info -->
    <div class="flex flex-1 flex-col gap-1 p-3">
      <p
        class="line-clamp-2 text-sm font-medium leading-tight text-n-slate-12"
        :title="product.item_name"
      >
        {{
          product.item_name ||
          t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.UNNAMED_PRODUCT')
        }}
      </p>

      <p class="text-sm font-semibold text-n-slate-12">
        {{ formattedPrice }}
      </p>

      <!-- Stock + bundle badges -->
      <div class="flex items-center gap-1.5">
        <span
          class="h-2 w-2 rounded-full"
          :class="isOutOfStock ? 'bg-n-slate-9' : 'bg-n-green-9'"
        />
        <span
          class="text-xs"
          :class="isOutOfStock ? 'text-n-slate-9' : 'text-n-slate-11'"
        >
          {{ stockLabel }}
        </span>
        <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
        <span
          v-if="product.is_bundle"
          class="rounded bg-n-blue-3 px-1.5 py-0.5 text-[10px] font-medium text-n-blue-11"
        >
          {{ t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.BUNDLE_BADGE') }}
        </span>
      </div>
    </div>

    <!-- Add button -->
    <div class="px-3 pb-3">
      <button
        class="flex w-full items-center justify-center gap-1 rounded-lg px-3 py-2 text-sm font-medium transition-colors"
        :class="
          isOutOfStock
            ? 'cursor-not-allowed bg-n-slate-3 text-n-slate-9'
            : 'bg-n-blue-9 text-white hover:bg-n-blue-10'
        "
        :disabled="isOutOfStock"
        :aria-label="
          t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.ADD_ARIA', {
            name: product.item_name,
          })
        "
        @click="$emit('add', product)"
      >
        <Icon icon="i-lucide-plus" size="14" />
        {{ t('CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL.ADD') }}
      </button>
    </div>
  </div>
</template>
