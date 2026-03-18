<script setup>
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import Input from 'dashboard/components-next/input/Input.vue';

defineProps({
  variants: { type: Array, default: () => [] },
});

const emit = defineEmits(['add', 'remove', 'update:variant']);
const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const navigateToVariant = index => {
  router.push({
    name: 'captain_variant_detail',
    params: { ...route.params, variantIndex: index },
  });
};
</script>

<template>
  <div class="space-y-3">
    <div class="flex items-center justify-between">
      <h3 class="text-xs font-semibold uppercase tracking-wider text-n-slate-9">
        {{ t('CAPTAIN_PRODUCTS.DETAIL.SECTION_VARIANTS') }}
        <span v-if="variants.length" class="text-n-slate-10 ml-1">
          ({{ variants.length }})
        </span>
      </h3>
      <button
        class="text-xs text-b-600 hover:text-b-700 font-medium"
        @click="emit('add')"
      >
        <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
        + {{ t('CAPTAIN_PRODUCTS.DETAIL.ADD_VARIANT') }}
      </button>
    </div>

    <!-- Variant table -->
    <div v-if="variants.length" class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-n-slate-3">
            <th class="text-left py-2 pr-3 text-xs font-medium text-n-slate-10">
              {{ t('CAPTAIN_PRODUCTS.FORM.VARIANT_NAME_PLACEHOLDER') }}
            </th>
            <th class="text-left py-2 pr-3 text-xs font-medium text-n-slate-10">
              {{ t('CAPTAIN_PRODUCTS.FORM.SKU_LABEL') }}
            </th>
            <th class="text-left py-2 pr-3 text-xs font-medium text-n-slate-10">
              {{ t('CAPTAIN_PRODUCTS.FORM.PRICE_LABEL') }}
            </th>
            <th class="w-16" />
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(variant, i) in variants"
            :key="i"
            class="border-b border-n-slate-2 hover:bg-n-alpha-1 group"
          >
            <td class="py-2 pr-3">
              <Input
                :model-value="variant.item_name"
                :placeholder="
                  t('CAPTAIN_PRODUCTS.FORM.VARIANT_NAME_PLACEHOLDER')
                "
                class="!mb-0"
                @update:model-value="
                  emit('update:variant', {
                    index: i,
                    field: 'item_name',
                    value: $event,
                  })
                "
              />
            </td>
            <td class="py-2 pr-3">
              <Input
                :model-value="variant.item_code"
                :placeholder="
                  t('CAPTAIN_PRODUCTS.FORM.VARIANT_SKU_PLACEHOLDER')
                "
                class="!mb-0 font-mono"
                @update:model-value="
                  emit('update:variant', {
                    index: i,
                    field: 'item_code',
                    value: $event,
                  })
                "
              />
            </td>
            <td class="py-2 pr-3">
              <Input
                :model-value="variant.price"
                type="number"
                :placeholder="
                  t('CAPTAIN_PRODUCTS.FORM.VARIANT_PRICE_PLACEHOLDER')
                "
                class="!mb-0 w-24"
                min="0"
                step="0.01"
                @update:model-value="
                  emit('update:variant', {
                    index: i,
                    field: 'price',
                    value: $event,
                  })
                "
              />
            </td>
            <td class="py-2">
              <div class="flex items-center gap-1">
                <button
                  class="p-1.5 rounded hover:bg-n-alpha-2 text-n-slate-9 hover:text-n-slate-12 opacity-0 group-hover:opacity-100 transition-opacity"
                  @click="navigateToVariant(i)"
                >
                  <span class="i-lucide-pencil w-4 h-4" />
                </button>
                <button
                  class="p-1.5 rounded hover:bg-r-50 text-n-slate-9 hover:text-r-500 opacity-0 group-hover:opacity-100 transition-opacity"
                  @click="emit('remove', i)"
                >
                  <span class="i-lucide-trash-2 w-4 h-4" />
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Empty variants -->
    <p v-else class="text-sm text-n-slate-9 italic">
      {{ t('CAPTAIN_PRODUCTS.DETAIL.NO_VARIANTS') }}
    </p>
  </div>
</template>
