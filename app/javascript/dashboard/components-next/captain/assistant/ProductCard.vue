<script setup>
import { computed } from 'vue';
import { useToggle } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { usePolicy } from 'dashboard/composables/usePolicy';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  id: {
    type: Number,
    required: true,
  },
  itemName: {
    type: String,
    default: '',
  },
  itemCode: {
    type: String,
    default: '',
  },
  price: {
    type: Number,
    default: null,
  },
  currency: {
    type: String,
    default: '',
  },
  stockQty: {
    type: Number,
    default: 0,
  },
  stockStatus: {
    type: String,
    default: 'unknown',
  },
  itemGroup: {
    type: String,
    default: '',
  },
  variants: {
    type: Array,
    default: () => [],
  },
  isExpanded: {
    type: Boolean,
    default: false,
  },
  imageUrl: {
    type: String,
    default: '',
  },
  erpCompany: {
    type: String,
    default: '',
  },
  selected: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['action', 'expand']);
const { checkPermissions } = usePolicy();
const { t } = useI18n();
const [showActionsDropdown, toggleDropdown] = useToggle();

const menuItems = computed(() => {
  const items = [
    {
      label: t('CAPTAIN_PRODUCTS.OPTIONS.VIEW_DESCRIPTION'),
      value: 'viewDescription',
      action: 'viewDescription',
      icon: 'i-lucide-eye',
    },
  ];

  if (checkPermissions(['administrator'])) {
    items.push(
      {
        label: t('CAPTAIN_PRODUCTS.OPTIONS.EDIT_DESCRIPTION'),
        value: 'editDescription',
        action: 'editDescription',
        icon: 'i-lucide-pencil',
      },
      {
        label: t('CAPTAIN_PRODUCTS.OPTIONS.AI_ENRICH'),
        value: 'aiEnrich',
        action: 'aiEnrich',
        icon: 'i-lucide-sparkles',
      },
      {
        label: t('CAPTAIN_PRODUCTS.OPTIONS.RESYNC'),
        value: 'resync',
        action: 'resync',
        icon: 'i-lucide-refresh-cw',
      },
      {
        label: t('CAPTAIN_PRODUCTS.OPTIONS.REMOVE'),
        value: 'delete',
        action: 'delete',
        icon: 'i-lucide-trash',
      }
    );
  }

  return items;
});

const formattedPrice = computed(() => {
  if (props.price == null) return '';
  return `${props.currency} ${Number(props.price).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
});

const stockLabel = computed(() => {
  if (props.stockStatus === 'in_stock') {
    return `${t('CAPTAIN_PRODUCTS.CARD.IN_STOCK')} (${props.stockQty})`;
  }
  if (props.stockStatus === 'out_of_stock') {
    return t('CAPTAIN_PRODUCTS.CARD.OUT_OF_STOCK');
  }
  return t('CAPTAIN_PRODUCTS.CARD.UNKNOWN_STOCK');
});

const stockDotColor = computed(() => {
  if (props.stockStatus === 'in_stock') return 'bg-g-400';
  if (props.stockStatus === 'out_of_stock') return 'bg-r-400';
  return 'bg-n-slate-8';
});

const isErpSynced = computed(() => !!props.erpCompany);

const sourceLabel = computed(() => {
  if (isErpSynced.value) return 'ERPNext';
  return t('CAPTAIN_PRODUCTS.CARD.SOURCE_MANUAL');
});

const sourceBadgeColor = computed(() => {
  if (isErpSynced.value) return 'bg-n-alpha-2 text-n-slate-11';
  return 'bg-b-50 text-b-700 dark:bg-b-900 dark:text-b-300';
});

const showItemCode = computed(() => {
  return props.itemCode && props.itemCode !== props.itemName;
});

const variantCount = computed(() => props.variants?.length || 0);

const handleAction = ({ action, value }) => {
  toggleDropdown(false);
  emit('action', { action, value, id: props.id });
};

const handleCardClick = () => {
  emit('expand', props.id);
};
</script>

<template>
  <CardLayout
    class="cursor-pointer transition-colors hover:bg-n-alpha-1"
    :class="{
      'ring-1 ring-woot-500/30': isExpanded,
      'ring-1 ring-b-500 bg-b-50/30 dark:bg-b-900/10': selected,
    }"
    @click="handleCardClick"
  >
    <div class="flex gap-3 w-full">
      <!-- Image thumbnail -->
      <div
        class="w-14 h-14 rounded-lg overflow-hidden bg-n-alpha-2 shrink-0 flex items-center justify-center"
      >
        <img
          v-if="imageUrl"
          :src="imageUrl"
          :alt="itemName"
          class="w-full h-full object-cover"
          @error="$event.target.style.display = 'none'"
        />
        <span v-else class="i-lucide-package w-6 h-6 text-n-slate-8" />
      </div>

      <div class="flex flex-col min-w-0 flex-1 gap-1">
        <div class="flex gap-1 justify-between">
          <div class="flex flex-col min-w-0 flex-1">
            <span class="text-base text-n-slate-12 line-clamp-1">
              {{ itemName }}
            </span>
            <span
              v-if="showItemCode"
              class="text-xs text-n-slate-10 line-clamp-1"
            >
              {{ itemCode }}
            </span>
          </div>
          <div class="flex gap-2 items-center shrink-0">
            <div
              v-on-clickaway="() => toggleDropdown(false)"
              class="flex relative items-center group"
              @click.stop
            >
              <Button
                icon="i-lucide-ellipsis-vertical"
                color="slate"
                size="xs"
                class="rounded-md group-hover:bg-n-alpha-2"
                @click="toggleDropdown()"
              />
              <DropdownMenu
                v-if="showActionsDropdown"
                :menu-items="menuItems"
                class="top-full mt-1 ltr:right-0 rtl:left-0 xl:ltr:right-0 xl:rtl:left-0"
                @action="handleAction($event)"
              />
            </div>
          </div>
        </div>
        <div class="flex gap-3 items-center flex-wrap text-sm text-n-slate-11">
          <span v-if="formattedPrice" class="shrink-0 font-medium">
            {{ formattedPrice }}
          </span>
          <span class="flex gap-1 items-center shrink-0">
            <span class="w-2 h-2 rounded-full" :class="stockDotColor" />
            {{ stockLabel }}
          </span>
          <span v-if="itemGroup" class="truncate">
            {{ itemGroup }}
          </span>
          <span
            v-if="variantCount > 0"
            class="text-xs text-n-slate-10 shrink-0"
          >
            {{ $t('CAPTAIN_PRODUCTS.VARIANTS.COUNT', { count: variantCount }) }}
          </span>
          <span
            class="inline-flex px-1.5 py-0.5 rounded text-xs font-medium shrink-0"
            :class="sourceBadgeColor"
          >
            {{ sourceLabel }}
          </span>
        </div>
      </div>
    </div>
  </CardLayout>
</template>
