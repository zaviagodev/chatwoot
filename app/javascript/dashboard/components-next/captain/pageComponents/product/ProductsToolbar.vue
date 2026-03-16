<script setup>
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';

import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

defineProps({
  totalCount: { type: Number, default: 0 },
  searchQuery: { type: String, default: '' },
  filterValue: { type: String, default: 'all' },
});

const emit = defineEmits([
  'update:searchQuery',
  'update:filterValue',
  'addFromErp',
  'addManually',
]);

const { t } = useI18n();
const [showAddDropdown, toggleAddDropdown] = useToggle();

const filterOptions = [
  { value: 'all', labelKey: 'CAPTAIN_PRODUCTS.TOOLBAR.FILTER_ALL' },
  { value: 'in_stock', labelKey: 'CAPTAIN_PRODUCTS.TOOLBAR.FILTER_IN_STOCK' },
  {
    value: 'out_of_stock',
    labelKey: 'CAPTAIN_PRODUCTS.TOOLBAR.FILTER_OUT_OF_STOCK',
  },
  { value: 'erp', labelKey: 'CAPTAIN_PRODUCTS.TOOLBAR.FILTER_ERP' },
  { value: 'manual', labelKey: 'CAPTAIN_PRODUCTS.TOOLBAR.FILTER_MANUAL' },
];

const addMenuItems = [
  {
    label: t('CAPTAIN_PRODUCTS.TOOLBAR.ADD_FROM_ERP'),
    value: 'addFromErp',
    action: 'addFromErp',
    icon: 'i-lucide-refresh-cw',
  },
  {
    label: t('CAPTAIN_PRODUCTS.TOOLBAR.ADD_MANUALLY'),
    value: 'addManually',
    action: 'addManually',
    icon: 'i-lucide-pencil',
  },
];

const handleAddAction = ({ action }) => {
  toggleAddDropdown(false);
  if (action === 'addFromErp') emit('addFromErp');
  else if (action === 'addManually') emit('addManually');
};

const handleAddClick = () => {
  toggleAddDropdown();
};
</script>

<template>
  <div class="flex flex-wrap items-center gap-3 mb-4">
    <!-- Search input -->
    <div class="relative flex-1 min-w-[180px]">
      <span
        class="absolute left-3 top-1/2 -translate-y-1/2 i-lucide-search w-4 h-4 text-n-slate-8"
      />
      <input
        :value="searchQuery"
        type="text"
        :placeholder="t('CAPTAIN_PRODUCTS.SEARCH.PLACEHOLDER')"
        class="!mb-0 !pl-9 !pr-8"
        @input="emit('update:searchQuery', $event.target.value)"
      />
      <button
        v-if="searchQuery"
        class="absolute right-2 top-1/2 -translate-y-1/2 p-0.5 rounded hover:bg-n-alpha-2 text-n-slate-9"
        @click="emit('update:searchQuery', '')"
      >
        <span class="i-lucide-x w-3.5 h-3.5" />
      </button>
    </div>

    <!-- Filter dropdown -->
    <select
      :value="filterValue"
      class="!mb-0 max-w-[160px]"
      @change="emit('update:filterValue', $event.target.value)"
    >
      <option v-for="opt in filterOptions" :key="opt.value" :value="opt.value">
        <!-- eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys -->
        {{ t(opt.labelKey) }}
      </option>
    </select>

    <!-- Product count -->
    <span class="text-xs text-n-slate-10 shrink-0">
      {{ t('CAPTAIN_PRODUCTS.TOOLBAR.PRODUCT_COUNT', { count: totalCount }) }}
    </span>

    <!-- Add product button with dropdown -->
    <div
      v-on-clickaway="() => toggleAddDropdown(false)"
      class="relative shrink-0"
    >
      <Button
        :label="t('CAPTAIN_PRODUCTS.TOOLBAR.ADD_PRODUCT')"
        icon="i-lucide-plus"
        size="sm"
        @click="handleAddClick"
      />
      <DropdownMenu
        v-if="showAddDropdown"
        :menu-items="addMenuItems"
        class="top-full mt-1 ltr:right-0 rtl:left-0"
        @action="handleAddAction($event)"
      />
    </div>
  </div>
</template>
