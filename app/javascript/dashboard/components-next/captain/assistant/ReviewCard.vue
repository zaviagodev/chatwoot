<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { usePolicy } from 'dashboard/composables/usePolicy';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  id: { type: Number, required: true },
  reviewerName: { type: String, default: '' },
  rating: { type: Number, default: null },
  reviewText: { type: String, default: '' },
  categoryTags: { type: Array, default: () => [] },
  photoUrls: { type: Array, default: () => [] },
  productName: { type: String, default: '' },
  selected: { type: Boolean, default: false },
});

const emit = defineEmits(['action', 'select']);

const { t } = useI18n();
const { checkPermissions } = usePolicy();
const isAdmin = computed(() => checkPermissions(['administrator']));

const displayName = computed(() => props.reviewerName || 'Anonymous');

const truncatedText = computed(() => {
  if (!props.reviewText) return '';
  return props.reviewText.length > 120
    ? props.reviewText.slice(0, 120) + '...'
    : props.reviewText;
});

const starDisplay = computed(() => {
  if (!props.rating) return [];
  return Array.from({ length: 5 }, (_, i) => i < props.rating);
});

const menuItems = computed(() => {
  if (!isAdmin.value) return [];
  return [
    {
      label: t('CAPTAIN_REVIEWS.DRAWER.EDIT_TITLE'),
      icon: 'i-lucide-pencil',
      action: 'edit',
    },
    {
      label: t('CAPTAIN_REVIEWS.DELETE.CONFIRM'),
      icon: 'i-lucide-trash',
      action: 'delete',
    },
  ];
});

const handleMenuAction = action => {
  emit('action', { action, id: props.id });
};
</script>

<template>
  <CardLayout>
    <div class="flex items-start gap-3 p-4">
      <!-- Checkbox for bulk select -->
      <Checkbox
        v-if="isAdmin"
        :model-value="selected"
        class="mt-1 shrink-0"
        @update:model-value="emit('select', id)"
      />

      <!-- Photo thumbnails -->
      <div v-if="photoUrls.length" class="flex gap-1.5 shrink-0">
        <img
          v-for="(url, idx) in photoUrls.slice(0, 4)"
          :key="idx"
          :src="url"
          :alt="`Review photo ${idx + 1}`"
          class="w-12 h-12 rounded-md object-cover bg-n-slate-3"
        />
      </div>
      <div
        v-else
        class="w-12 h-12 rounded-md bg-n-slate-3 flex items-center justify-center shrink-0"
      >
        <span class="i-lucide-camera text-n-slate-8 text-lg" />
      </div>

      <!-- Content -->
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2 mb-1">
          <span class="text-sm font-medium text-n-slate-12 truncate">
            {{ displayName }}
          </span>
          <!-- Star rating -->
          <div v-if="rating" class="flex items-center gap-0.5">
            <span
              v-for="(filled, idx) in starDisplay"
              :key="idx"
              class="text-xs"
              :class="
                filled
                  ? 'i-lucide-star text-y-500'
                  : 'i-lucide-star text-n-slate-6'
              "
            />
          </div>
        </div>

        <!-- Product badge -->
        <div v-if="productName" class="mb-1.5">
          <span
            class="inline-flex items-center gap-1 text-xs px-1.5 py-0.5 rounded bg-b-50 text-b-600 dark:bg-b-900 dark:text-b-300"
          >
            <span class="i-lucide-package text-xs" />
            {{ productName }}
          </span>
        </div>

        <p
          v-if="truncatedText"
          class="text-sm text-n-slate-11 mb-1.5 line-clamp-2"
        >
          {{ truncatedText }}
        </p>

        <!-- Tags -->
        <div v-if="categoryTags.length" class="flex flex-wrap gap-1">
          <span
            v-for="tag in categoryTags"
            :key="tag"
            class="text-xs px-1.5 py-0.5 rounded bg-n-slate-3 text-n-slate-11"
          >
            {{ tag }}
          </span>
        </div>
      </div>

      <!-- Three-dot menu -->
      <DropdownMenu
        v-if="isAdmin && menuItems.length"
        :menu-items="menuItems"
        class="shrink-0"
        @action="handleMenuAction"
      >
        <template #trigger>
          <button class="p-1 rounded hover:bg-n-slate-3 text-n-slate-9">
            <span class="i-lucide-more-vertical text-base" />
          </button>
        </template>
      </DropdownMenu>
    </div>
  </CardLayout>
</template>
