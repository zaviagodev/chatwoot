<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import VariantRow from './VariantRow.vue';

const props = defineProps({
  variants: {
    type: Array,
    default: () => [],
  },
  currency: {
    type: String,
    default: 'THB',
  },
  parentPrice: {
    type: Number,
    default: 0,
  },
});

const emit = defineEmits(['toggle', 'bulkToggle']);

const TRUNCATE_AT = 5;

const { t } = useI18n();

const showAll = ref(false);

const needsTruncation = computed(() => props.variants.length > TRUNCATE_AT);
const displayedVariants = computed(() => {
  if (!needsTruncation.value || showAll.value) return props.variants;
  return props.variants.slice(0, TRUNCATE_AT);
});

const enabledCount = computed(
  () => props.variants.filter(v => v.enabled !== false).length
);
const allEnabled = computed(() => enabledCount.value === props.variants.length);

const bulkToggleLabel = computed(() =>
  allEnabled.value
    ? t('CAPTAIN_PRODUCTS.VARIANTS.DISABLE_ALL')
    : t('CAPTAIN_PRODUCTS.VARIANTS.ENABLE_ALL')
);

const handleToggle = itemCode => {
  emit('toggle', itemCode);
};

const handleBulkToggle = () => {
  emit('bulkToggle', !allEnabled.value);
};
</script>

<template>
  <div v-if="variants.length" class="mt-3">
    <div class="border-t border-n-strong mb-3" />
    <div class="flex items-center justify-between mb-2 px-3">
      <span class="text-xs font-medium text-n-slate-11">
        {{ t('CAPTAIN_PRODUCTS.VARIANTS.HEADER', { count: variants.length }) }}
      </span>
      <button
        class="text-xs text-woot-500 hover:text-woot-600 dark:hover:text-woot-400"
        @click="handleBulkToggle"
      >
        {{ bulkToggleLabel }}
      </button>
    </div>

    <div class="flex flex-col gap-0.5">
      <VariantRow
        v-for="variant in displayedVariants"
        :key="variant.item_code"
        :variant="variant"
        :currency="currency"
        :parent-price="parentPrice"
        @toggle="handleToggle"
      />
    </div>

    <button
      v-if="needsTruncation"
      class="w-full text-center text-xs text-woot-500 hover:text-woot-600 dark:hover:text-woot-400 py-2"
      @click="showAll = !showAll"
    >
      {{
        showAll
          ? t('CAPTAIN_PRODUCTS.VARIANTS.SHOW_FEWER')
          : t('CAPTAIN_PRODUCTS.VARIANTS.SHOW_ALL', {
              count: variants.length,
            })
      }}
    </button>
  </div>
</template>
