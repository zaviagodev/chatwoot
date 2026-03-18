<script setup>
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';

defineProps({
  currency: { type: String, default: 'THB' },
  price: { type: String, default: '' },
  stockQty: { type: String, default: '' },
  specs: { type: Array, default: () => [] },
  formattedText: { type: String, default: '' },
  errors: { type: Object, default: () => ({}) },
});

const emit = defineEmits([
  'update:currency',
  'update:price',
  'update:stockQty',
  'addSpec',
  'removeSpec',
  'update:spec',
]);

const { t } = useI18n();

const currencies = ['THB', 'USD', 'EUR', 'JPY', 'GBP', 'CNY', 'SGD'];
</script>

<template>
  <div class="space-y-6">
    <!-- Pricing & Stock card -->
    <CardLayout>
      <div class="space-y-3">
        <h3
          class="text-xs font-semibold uppercase tracking-wider text-n-slate-9"
        >
          {{ t('CAPTAIN_PRODUCTS.DETAIL.SECTION_PRICING') }}
        </h3>
        <div class="flex gap-3">
          <div class="w-24">
            <label class="text-sm text-n-slate-12 block mb-1">
              {{ t('CAPTAIN_PRODUCTS.FORM.CURRENCY_LABEL') }}
            </label>
            <select
              :value="currency"
              class="!mb-0"
              @change="emit('update:currency', $event.target.value)"
            >
              <option v-for="c in currencies" :key="c" :value="c">
                {{ c }}
              </option>
            </select>
          </div>
          <div class="flex-1">
            <label class="text-sm text-n-slate-12 block mb-1">
              {{ t('CAPTAIN_PRODUCTS.FORM.PRICE_LABEL') }}
              <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
              <span class="text-r-500">*</span>
            </label>
            <Input
              :model-value="price"
              type="number"
              :placeholder="t('CAPTAIN_PRODUCTS.FORM.PRICE_PLACEHOLDER')"
              min="0"
              step="0.01"
              :class="{ 'border-r-500': errors.price }"
              @update:model-value="emit('update:price', $event)"
            />
            <span v-if="errors.price" class="text-xs text-r-500 mt-0.5 block">
              {{ errors.price }}
            </span>
          </div>
        </div>
        <div>
          <label class="text-sm text-n-slate-12 block mb-1">
            {{ t('CAPTAIN_PRODUCTS.FORM.STOCK_LABEL') }}
          </label>
          <Input
            :model-value="stockQty"
            type="number"
            :placeholder="t('CAPTAIN_PRODUCTS.FORM.STOCK_PLACEHOLDER')"
            min="0"
            @update:model-value="emit('update:stockQty', $event)"
          />
          <p class="text-xs text-n-slate-9 mt-1">
            {{ t('CAPTAIN_PRODUCTS.DETAIL.STOCK_HELPER') }}
          </p>
          <span
            v-if="stockQty === '0'"
            class="inline-flex px-2 py-0.5 rounded text-xs font-medium bg-n-amber-3 text-n-amber-11 mt-1"
          >
            {{ t('CAPTAIN_PRODUCTS.DETAIL.STOCK_OUT') }}
          </span>
          <span
            v-else-if="stockQty === ''"
            class="text-xs text-n-slate-9 mt-1 block"
          >
            {{ t('CAPTAIN_PRODUCTS.DETAIL.STOCK_NOT_TRACKED') }}
          </span>
        </div>
      </div>
    </CardLayout>

    <!-- Specifications card -->
    <CardLayout>
      <div class="space-y-3">
        <div class="flex items-center justify-between">
          <h3
            class="text-xs font-semibold uppercase tracking-wider text-n-slate-9"
          >
            {{ t('CAPTAIN_PRODUCTS.DETAIL.SECTION_SPECS') }}
          </h3>
          <button
            class="text-xs text-b-600 hover:text-b-700 font-medium"
            @click="emit('addSpec')"
          >
            <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
            + {{ t('CAPTAIN_PRODUCTS.DETAIL.ADD_SPEC') }}
          </button>
        </div>
        <div v-if="specs.length" class="space-y-2">
          <div
            v-for="(spec, i) in specs"
            :key="i"
            class="flex gap-2 items-start group"
          >
            <Input
              :model-value="spec.label"
              :placeholder="t('CAPTAIN_PRODUCTS.FORM.SPEC_KEY_PLACEHOLDER')"
              class="flex-1 !mb-0"
              @update:model-value="
                emit('update:spec', { index: i, field: 'label', value: $event })
              "
            />
            <Input
              :model-value="spec.value"
              :placeholder="t('CAPTAIN_PRODUCTS.FORM.SPEC_VALUE_PLACEHOLDER')"
              class="flex-1 !mb-0"
              @update:model-value="
                emit('update:spec', { index: i, field: 'value', value: $event })
              "
            />
            <button
              class="p-1.5 rounded hover:bg-r-50 text-n-slate-9 hover:text-r-500 opacity-0 group-hover:opacity-100 transition-opacity shrink-0 mt-1"
              @click="emit('removeSpec', i)"
            >
              <span class="i-lucide-trash-2 w-4 h-4" />
            </button>
          </div>
        </div>
        <p v-else class="text-sm text-n-slate-9 italic">
          {{ t('CAPTAIN_PRODUCTS.DETAIL.NO_SPECS') }}
        </p>
      </div>
    </CardLayout>

    <!-- Captain AI Preview card -->
    <CardLayout class="border-l-4 border-b-500">
      <div class="space-y-3">
        <div class="flex items-center gap-2">
          <h3
            class="text-xs font-semibold uppercase tracking-wider text-n-slate-9"
          >
            {{ t('CAPTAIN_PRODUCTS.DETAIL.SECTION_CAPTAIN_PREVIEW') }}
          </h3>
          <span
            class="i-lucide-info w-3.5 h-3.5 text-n-slate-9 cursor-help"
            :title="t('CAPTAIN_PRODUCTS.DETAIL.CAPTAIN_PREVIEW_TOOLTIP')"
          />
        </div>
        <pre
          v-if="formattedText"
          class="text-xs font-mono whitespace-pre-wrap bg-n-alpha-2 rounded-lg p-4 text-n-slate-11 max-h-80 overflow-y-auto"
          :aria-label="t('CAPTAIN_PRODUCTS.DETAIL.CAPTAIN_PREVIEW_ARIA')"
          >{{ formattedText }}</pre
        >
        <p v-else class="text-sm text-n-slate-9 italic">
          {{ t('CAPTAIN_PRODUCTS.DETAIL.CAPTAIN_PREVIEW_EMPTY') }}
        </p>
      </div>
    </CardLayout>
  </div>
</template>
