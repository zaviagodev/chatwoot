<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import CaptainErpProxy from 'dashboard/api/captain/erpProxy';
import Icon from 'next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  assistantId: { type: Number, required: true },
  deliveryState: {
    type: String,
    default: 'loading',
    validator: v =>
      ['loading', 'member', 'new_customer', 'no_line', 'error'].includes(v),
  },
  customerData: { type: Object, default: null },
  selectedAddress: { type: String, default: null },
  addressForm: {
    type: Object,
    default: () => ({
      name: '',
      phone: '',
      address_line1: '',
      city: '',
      state: '',
      pincode: '',
      notes: '',
    }),
  },
  registerCustomer: { type: Boolean, default: false },
});

const emit = defineEmits([
  'select-address',
  'update:address-form',
  'update:register-customer',
  'back',
]);

const { t } = useI18n();
const I18N = 'CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL';

// Computed
const addresses = computed(() => props.customerData?.addresses || []);
const displayName = computed(
  () =>
    props.customerData?.display_name || props.customerData?.customer_name || ''
);

const showAddressForm = computed(() => {
  if (
    props.deliveryState === 'new_customer' ||
    props.deliveryState === 'no_line' ||
    props.deliveryState === 'error'
  ) {
    return true;
  }
  // Member who clicked "Use different address"
  if (props.deliveryState === 'member' && props.selectedAddress === null) {
    return true;
  }
  return false;
});

// Soft validation (show errors after blur)
const touched = ref({
  name: false,
  phone: false,
  address_line1: false,
  city: false,
  state: false,
  pincode: false,
});

const fieldError = field => {
  return touched.value[field] && !props.addressForm[field]?.trim();
};

// Field update helper
const updateField = (field, value) => {
  emit('update:address-form', { ...props.addressForm, [field]: value });
};

// Thai address autocomplete
const autocompleteResults = ref([]);
const showAutocomplete = ref(false);
const autocompleteField = ref(null);
const stepRef = ref(null);

const searchThaiAddress = async query => {
  if (!query || query.length < 2) {
    autocompleteResults.value = [];
    showAutocomplete.value = false;
    return;
  }
  try {
    const { data } = await CaptainErpProxy.searchThaiAddress({
      assistantId: props.assistantId,
      query,
    });
    const results = Array.isArray(data)
      ? data
      : data?.data || data?.message || [];
    autocompleteResults.value = results;
    showAutocomplete.value = results.length > 0;
  } catch {
    autocompleteResults.value = [];
    showAutocomplete.value = false;
  }
};

const debouncedThaiSearch = debounce(query => {
  searchThaiAddress(query);
}, 300);

const onCityInput = value => {
  updateField('city', value);
  autocompleteField.value = 'city';
  debouncedThaiSearch(value);
};

const onPostalInput = value => {
  updateField('pincode', value);
  autocompleteField.value = 'pincode';
  debouncedThaiSearch(value);
};

const selectThaiAddress = result => {
  emit('update:address-form', {
    ...props.addressForm,
    city: result.district,
    state: result.province,
    pincode: result.postal_code,
  });
  showAutocomplete.value = false;
  autocompleteResults.value = [];
};

// Address card formatting
const formatAddressMain = addr => {
  const parts = [addr.address_line1, addr.city, addr.pincode].filter(Boolean);
  return parts.join(', ');
};

const formatAddressMeta = addr => {
  const parts = [addr.address_title, addr.phone].filter(Boolean);
  return parts.join(' \u00B7 ');
};

// Close autocomplete on click outside
const onClickOutside = e => {
  if (stepRef.value && !stepRef.value.contains(e.target)) {
    showAutocomplete.value = false;
  }
};

onMounted(() => document.addEventListener('mousedown', onClickOutside));
onUnmounted(() => {
  document.removeEventListener('mousedown', onClickOutside);
  if (debouncedThaiSearch.cancel) debouncedThaiSearch.cancel();
});
</script>

<template>
  <div ref="stepRef" class="flex flex-col p-6">
    <!-- Back link -->
    <button
      class="mb-4 flex items-center gap-1 self-start text-sm text-n-blue-11 transition-colors hover:text-n-blue-12"
      @click="emit('back')"
    >
      <Icon icon="i-lucide-arrow-left" size="14" />
      {{ t(`${I18N}.BACK_PRODUCTS`) }}
    </button>

    <!-- Section heading -->
    <h3 class="mb-4 text-lg font-semibold text-n-slate-12">
      {{ t(`${I18N}.DELIVERY_TITLE`) }}
    </h3>

    <!-- Loading state -->
    <div
      v-if="deliveryState === 'loading'"
      class="flex flex-1 flex-col items-center justify-center gap-3 py-12"
    >
      <Spinner />
      <p class="text-sm text-n-slate-11">
        {{ t(`${I18N}.DELIVERY_LOADING`) }}
      </p>
    </div>

    <!-- Member state: saved addresses -->
    <template v-else-if="deliveryState === 'member'">
      <div class="mb-4 flex items-center gap-2" aria-live="polite">
        <Icon
          icon="i-lucide-check-circle"
          size="16"
          class="shrink-0 text-n-green-11"
        />
        <span class="text-sm font-medium text-n-slate-12">
          {{ t(`${I18N}.DELIVERY_MEMBER`, { name: displayName }) }}
        </span>
      </div>

      <!-- Address radio group -->
      <div
        role="radiogroup"
        :aria-label="t(`${I18N}.DELIVERY_TITLE`)"
        class="mb-4 flex flex-col gap-3"
      >
        <button
          v-for="addr in addresses"
          :key="addr.name"
          role="radio"
          :aria-checked="selectedAddress === addr.name"
          :aria-label="
            t(`${I18N}.DELIVERY_ADDRESS_ARIA`, {
              title: addr.address_title || addr.name,
              address: formatAddressMain(addr),
            })
          "
          class="w-full rounded-lg border px-4 py-3 text-left transition-colors"
          :class="
            selectedAddress === addr.name
              ? 'border-n-blue-7 bg-n-blue-2'
              : 'border-n-weak hover:border-n-blue-7'
          "
          @click="emit('select-address', addr.name)"
        >
          <p class="text-sm font-medium text-n-slate-12">
            {{ formatAddressMain(addr) }}
          </p>
          <p class="mt-0.5 text-xs text-n-slate-10">
            {{ formatAddressMeta(addr) }}
          </p>
        </button>
      </div>

      <!-- Use different address link -->
      <button
        v-if="selectedAddress !== null"
        class="mb-4 text-sm text-n-blue-11 transition-colors hover:text-n-blue-12"
        @click="emit('select-address', null)"
      >
        {{ t(`${I18N}.DELIVERY_USE_DIFFERENT`) }}
      </button>
    </template>

    <!-- New customer state -->
    <template v-else-if="deliveryState === 'new_customer'">
      <p class="mb-4 text-sm text-n-slate-10" aria-live="polite">
        {{ t(`${I18N}.DELIVERY_NEW_CUSTOMER`) }}
      </p>
    </template>

    <!-- No LINE / error fallback -->
    <template
      v-else-if="deliveryState === 'no_line' || deliveryState === 'error'"
    >
      <p
        v-if="deliveryState === 'error'"
        class="mb-4 text-sm text-n-slate-10"
        aria-live="polite"
      >
        {{ t(`${I18N}.DELIVERY_LOOKUP_ERROR`) }}
      </p>
    </template>

    <!-- Manual address form -->
    <div v-if="showAddressForm" class="flex flex-col gap-4">
      <!-- Name + Phone (2 columns) -->
      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="mb-1 block text-xs font-medium text-n-slate-11">
            {{ t(`${I18N}.DELIVERY_FIELD_NAME`) }}
            <span class="text-n-ruby-11">*</span>
          </label>
          <input
            :value="addressForm.name"
            class="w-full rounded-lg border bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition-colors focus:border-n-blue-7 focus:ring-1 focus:ring-n-blue-7"
            :class="fieldError('name') ? 'border-n-ruby-7' : 'border-n-weak'"
            @input="updateField('name', $event.target.value)"
            @blur="touched.name = true"
          />
        </div>
        <div>
          <label class="mb-1 block text-xs font-medium text-n-slate-11">
            {{ t(`${I18N}.DELIVERY_FIELD_PHONE`) }}
            <span class="text-n-ruby-11">*</span>
          </label>
          <input
            :value="addressForm.phone"
            class="w-full rounded-lg border bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition-colors focus:border-n-blue-7 focus:ring-1 focus:ring-n-blue-7"
            :class="fieldError('phone') ? 'border-n-ruby-7' : 'border-n-weak'"
            @input="updateField('phone', $event.target.value)"
            @blur="touched.phone = true"
          />
        </div>
      </div>

      <!-- Address line 1 -->
      <div>
        <label class="mb-1 block text-xs font-medium text-n-slate-11">
          {{ t(`${I18N}.DELIVERY_FIELD_ADDRESS`) }}
          <span class="text-n-ruby-11">*</span>
        </label>
        <input
          :value="addressForm.address_line1"
          class="w-full rounded-lg border bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition-colors focus:border-n-blue-7 focus:ring-1 focus:ring-n-blue-7"
          :class="
            fieldError('address_line1') ? 'border-n-ruby-7' : 'border-n-weak'
          "
          @input="updateField('address_line1', $event.target.value)"
          @blur="touched.address_line1 = true"
        />
      </div>

      <!-- City + Province (2 columns) -->
      <div class="grid grid-cols-2 gap-4">
        <div class="relative">
          <label class="mb-1 block text-xs font-medium text-n-slate-11">
            {{ t(`${I18N}.DELIVERY_FIELD_CITY`) }}
            <span class="text-n-ruby-11">*</span>
          </label>
          <input
            :value="addressForm.city"
            class="w-full rounded-lg border bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition-colors focus:border-n-blue-7 focus:ring-1 focus:ring-n-blue-7"
            :class="fieldError('city') ? 'border-n-ruby-7' : 'border-n-weak'"
            :placeholder="t(`${I18N}.DELIVERY_AUTOCOMPLETE_HINT`)"
            @input="onCityInput($event.target.value)"
            @blur="touched.city = true"
          />
          <!-- Thai address autocomplete dropdown (City) -->
          <ul
            v-if="showAutocomplete && autocompleteField === 'city'"
            class="absolute z-10 mt-1 w-full max-h-[200px] overflow-y-auto rounded-lg border border-n-weak bg-n-solid-1 shadow-lg"
          >
            <li
              v-for="(result, idx) in autocompleteResults"
              :key="idx"
              class="cursor-pointer px-3 py-2 text-sm text-n-slate-12 transition-colors hover:bg-n-blue-2"
              @mousedown.prevent="selectThaiAddress(result)"
            >
              <span class="font-medium">{{ result.subdistrict }}</span>
              <span class="text-n-slate-10">
                , {{ result.district }}, {{ result.province }}
                {{ result.postal_code }}
              </span>
            </li>
            <li
              v-if="autocompleteResults.length === 0"
              class="px-3 py-2 text-sm text-n-slate-9"
            >
              {{ t(`${I18N}.DELIVERY_NO_RESULTS`) }}
            </li>
          </ul>
        </div>
        <div>
          <label class="mb-1 block text-xs font-medium text-n-slate-11">
            {{ t(`${I18N}.DELIVERY_FIELD_PROVINCE`) }}
            <span class="text-n-ruby-11">*</span>
          </label>
          <input
            :value="addressForm.state"
            class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition-colors focus:border-n-blue-7 focus:ring-1 focus:ring-n-blue-7"
            @input="updateField('state', $event.target.value)"
            @blur="touched.state = true"
          />
        </div>
      </div>

      <!-- Postal Code -->
      <div class="w-1/3 relative">
        <label class="mb-1 block text-xs font-medium text-n-slate-11">
          {{ t(`${I18N}.DELIVERY_FIELD_POSTAL`) }}
          <span class="text-n-ruby-11">*</span>
        </label>
        <input
          :value="addressForm.pincode"
          class="w-full rounded-lg border bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition-colors focus:border-n-blue-7 focus:ring-1 focus:ring-n-blue-7"
          :class="fieldError('pincode') ? 'border-n-ruby-7' : 'border-n-weak'"
          @input="onPostalInput($event.target.value)"
          @blur="touched.pincode = true"
        />
        <!-- Thai address autocomplete dropdown (Postal) -->
        <ul
          v-if="showAutocomplete && autocompleteField === 'pincode'"
          class="absolute z-10 mt-1 w-full min-w-[300px] max-h-[200px] overflow-y-auto rounded-lg border border-n-weak bg-n-solid-1 shadow-lg"
        >
          <li
            v-for="(result, idx) in autocompleteResults"
            :key="idx"
            class="cursor-pointer px-3 py-2 text-sm text-n-slate-12 transition-colors hover:bg-n-blue-2"
            @mousedown.prevent="selectThaiAddress(result)"
          >
            <span class="font-medium">{{ result.postal_code }}</span>
            <span class="text-n-slate-10">
              &mdash; {{ result.subdistrict }}, {{ result.district }},
              {{ result.province }}
            </span>
          </li>
        </ul>
      </div>

      <!-- Notes (optional) -->
      <div>
        <label class="mb-1 block text-xs font-medium text-n-slate-11">
          {{ t(`${I18N}.DELIVERY_FIELD_NOTES`) }}
        </label>
        <textarea
          :value="addressForm.notes"
          rows="2"
          class="w-full resize-none rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition-colors focus:border-n-blue-7 focus:ring-1 focus:ring-n-blue-7"
          @input="updateField('notes', $event.target.value)"
        />
      </div>

      <!-- Register checkbox (new LINE customer only) -->
      <label
        v-if="deliveryState === 'new_customer'"
        class="flex cursor-pointer items-center gap-2"
        :aria-label="t(`${I18N}.DELIVERY_REGISTER`)"
      >
        <input
          type="checkbox"
          :checked="registerCustomer"
          class="rounded"
          @change="emit('update:register-customer', $event.target.checked)"
        />
        <span class="text-sm text-n-slate-11">
          {{ t(`${I18N}.DELIVERY_REGISTER`) }}
        </span>
      </label>
    </div>
  </div>
</template>
