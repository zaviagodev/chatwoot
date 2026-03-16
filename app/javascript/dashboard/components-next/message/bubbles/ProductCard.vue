<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import BaseBubble from './Base.vue';
import { useMessageContext } from '../provider.js';

const { t } = useI18n();

const { contentAttributes } = useMessageContext();

const isCarousel = computed(
  () =>
    Array.isArray(contentAttributes.value?.products) &&
    contentAttributes.value.products.length > 0
);

const product = computed(() => {
  if (isCarousel.value) {
    return contentAttributes.value.products[0] || {};
  }
  return contentAttributes.value?.product || {};
});

const carouselCount = computed(() =>
  isCarousel.value ? contentAttributes.value.products.length : 0
);

const hasImage = computed(() => !!product.value.image_url);

const formattedPrice = computed(() => {
  const { price, currency } = product.value;
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
</script>

<template>
  <BaseBubble class="overflow-hidden p-0" data-bubble-name="product-card">
    <div class="w-72">
      <div
        v-if="hasImage"
        class="w-full aspect-video bg-n-slate-3 overflow-hidden"
      >
        <img
          :src="product.image_url"
          :alt="product.item_name"
          class="w-full h-full object-cover"
        />
      </div>
      <div class="p-3">
        <p class="text-sm font-semibold mb-1 text-n-slate-12 leading-snug">
          {{ product.item_name }}
        </p>
        <p v-if="formattedPrice" class="text-sm text-n-slate-11 mb-2">
          {{ formattedPrice }}
        </p>
        <p class="text-xs text-n-slate-9">
          {{ t('CONVERSATION.REPLYBOX.PRODUCT_PICKER.PRODUCT_CARD_LABEL') }}
        </p>
        <p
          v-if="isCarousel && carouselCount > 1"
          class="text-xs text-n-blue-11 mt-1"
        >
          {{ `+${carouselCount - 1}` }}
          {{ t('CONVERSATION.REPLYBOX.CARD_PICKER.CAROUSEL_MORE_CARDS') }}
        </p>
      </div>
    </div>
  </BaseBubble>
</template>
