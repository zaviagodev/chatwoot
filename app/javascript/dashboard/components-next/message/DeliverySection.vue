<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import CaptainErpProxy from 'dashboard/api/captain/erpProxy';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  lookupState: {
    type: String,
    default: 'loading',
    validator: v =>
      ['loading', 'member', 'new_customer', 'no_line', 'error'].includes(v),
  },
  customerData: {
    type: Object,
    default: null,
  },
  selectedAddress: {
    type: String,
    default: null,
  },
  addressForm: {
    type: Object,
    default: () => ({
      name: '',
      phone: '',
      address_line1: '',
      city: '',
      state: '',
      pincode: '',
    }),
  },
  registerCustomer: {
    type: Boolean,
    default: false,
  },
  assistantId: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits([
  'selectAddress',
  'update:address-form',
  'update:register-customer',
]);

const { t } = useI18n();
const I18N = 'CONVERSATION.REPLYBOX.ORDER_BUILDER';

const addresses = computed(() => props.customerData?.addresses || []);

const displayName = computed(
  () =>
    props.customerData?.display_name || props.customerData?.customer_name || ''
);

const selectAddress = name => {
  emit('selectAddress', name);
};

const formatAddressLine1 = addr => {
  const parts = [addr.address_line1, addr.city, addr.pincode].filter(Boolean);
  return parts.join(', ');
};

const formatAddressLine2 = addr => {
  const parts = [addr.address_title, addr.phone].filter(Boolean);
  return parts.join(' • ');
};

// Form visibility: show in States B/C, or State A with "+ Enter new address"
const showAddressForm = computed(() => {
  if (
    props.lookupState === 'new_customer' ||
    props.lookupState === 'no_line' ||
    props.lookupState === 'error'
  ) {
    return true;
  }
  if (props.lookupState === 'member' && props.selectedAddress === null) {
    return true;
  }
  return false;
});

// Soft validation (red border on blur if empty)
const touched = ref({ name: false, phone: false });
const nameError = computed(
  () => touched.value.name && !props.addressForm.name?.trim()
);
const phoneError = computed(
  () => touched.value.phone && !props.addressForm.phone?.trim()
);

// Field update helper — emits new object to parent
const updateField = (field, value) => {
  emit('update:address-form', { ...props.addressForm, [field]: value });
};

// Thai address autocomplete
const autocompleteResults = ref([]);
const showAutocomplete = ref(false);
const autocompleteField = ref(null); // 'city' or 'pincode'
const deliveryRef = ref(null);

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

// Close autocomplete on click outside
const onClickOutside = e => {
  if (deliveryRef.value && !deliveryRef.value.contains(e.target)) {
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
  <div ref="deliveryRef" class="border-t border-n-slate-6">
    <!-- Section header -->
    <div class="px-3 pt-2 pb-1">
      <span
        class="text-xs font-semibold text-n-slate-9 uppercase tracking-wide"
      >
        {{ t(`${I18N}.DELIVERY`) }}
      </span>
    </div>

    <div class="px-3 pb-2">
      <!-- Loading state: shimmer skeleton -->
      <div
        v-if="lookupState === 'loading'"
        class="h-4 rounded bg-n-slate-3 animate-pulse"
      />

      <!-- State A: Returning member with addresses -->
      <template v-else-if="lookupState === 'member'">
        <!-- Membership status -->
        <div class="flex items-center gap-1.5 mb-2" aria-live="polite">
          <Icon
            icon="i-lucide-check-circle"
            size="14"
            class="text-n-green-11 flex-shrink-0"
          />
          <span class="text-sm font-medium text-n-slate-12">
            {{ t(`${I18N}.STOREFRONT_MEMBER`, { name: displayName }) }}
          </span>
        </div>

        <!-- Address radio group -->
        <div
          role="radiogroup"
          :aria-label="t(`${I18N}.DELIVERY`)"
          class="flex flex-col gap-2 max-h-[140px] overflow-y-auto"
        >
          <!-- Saved addresses -->
          <button
            v-for="addr in addresses"
            :key="addr.name"
            role="radio"
            :aria-checked="selectedAddress === addr.name"
            class="w-full text-left px-3 py-2 rounded-lg border transition-colors"
            :class="
              selectedAddress === addr.name
                ? 'border-n-blue-7 bg-n-blue-2'
                : 'border-n-slate-6 hover:border-n-blue-7'
            "
            @click="selectAddress(addr.name)"
          >
            <p class="text-sm text-n-slate-12 leading-tight">
              {{ formatAddressLine1(addr) }}
            </p>
            <p class="text-xs text-n-slate-10 mt-0.5">
              {{ formatAddressLine2(addr) }}
            </p>
          </button>

          <!-- + Enter new address option -->
          <button
            role="radio"
            :aria-checked="selectedAddress === null"
            class="w-full text-left px-3 py-2 rounded-lg border transition-colors"
            :class="
              selectedAddress === null
                ? 'border-n-blue-7 bg-n-blue-2'
                : 'border-n-slate-6 hover:border-n-blue-7'
            "
            @click="selectAddress(null)"
          >
            <span class="text-sm text-n-slate-11">
              {{ t(`${I18N}.ENTER_NEW_ADDRESS`) }}
            </span>
          </button>
        </div>
      </template>

      <!-- State B: New LINE customer (no storefront account) -->
      <template v-else-if="lookupState === 'new_customer'">
        <p class="text-sm text-n-slate-10" aria-live="polite">
          {{ t(`${I18N}.NO_ACCOUNT_FOUND`) }}
        </p>
      </template>

      <!-- State C: Non-LINE channel or error fallback -->
      <!-- (no status text needed — just the form below) -->

      <!-- Address form (States B/C, or State A with "+ Enter new address") -->
      <div v-if="showAddressForm" class="mt-2 flex flex-col gap-2">
        <!-- Name -->
        <div>
          <label class="text-xs font-medium text-n-slate-11">
            {{ t(`${I18N}.FIELD_NAME`) }}
            <span class="text-red-500">*</span>
          </label>
          <input
            :value="addressForm.name"
            class="w-full text-sm border rounded-md px-3 py-1.5 mt-0.5"
            :class="nameError ? 'border-red-500' : 'border-n-slate-6'"
            @input="updateField('name', $event.target.value)"
            @blur="touched.name = true"
          />
        </div>

        <!-- Phone -->
        <div>
          <label class="text-xs font-medium text-n-slate-11">
            {{ t(`${I18N}.FIELD_PHONE`) }}
            <span class="text-red-500">*</span>
          </label>
          <input
            :value="addressForm.phone"
            class="w-full text-sm border rounded-md px-3 py-1.5 mt-0.5"
            :class="phoneError ? 'border-red-500' : 'border-n-slate-6'"
            @input="updateField('phone', $event.target.value)"
            @blur="touched.phone = true"
          />
        </div>

        <!-- Address -->
        <div>
          <label class="text-xs font-medium text-n-slate-11">
            {{ t(`${I18N}.FIELD_ADDRESS`) }}
          </label>
          <input
            :value="addressForm.address_line1"
            class="w-full text-sm border border-n-slate-6 rounded-md px-3 py-1.5 mt-0.5"
            @input="updateField('address_line1', $event.target.value)"
          />
        </div>

        <!-- City + Province (2-column) -->
        <div class="grid grid-cols-2 gap-2">
          <div class="relative">
            <label class="text-xs font-medium text-n-slate-11">
              {{ t(`${I18N}.FIELD_CITY`) }}
            </label>
            <input
              :value="addressForm.city"
              class="w-full text-sm border border-n-slate-6 rounded-md px-3 py-1.5 mt-0.5"
              @input="onCityInput($event.target.value)"
            />
            <!-- Thai address autocomplete dropdown (City) -->
            <ul
              v-if="showAutocomplete && autocompleteField === 'city'"
              class="absolute z-10 mt-1 w-full max-h-[160px] overflow-y-auto bg-white dark:bg-n-slate-2 border border-n-slate-6 rounded-md shadow-lg"
            >
              <li
                v-for="(result, idx) in autocompleteResults"
                :key="idx"
                class="px-3 py-1.5 text-sm text-n-slate-12 hover:bg-n-blue-2 cursor-pointer"
                @mousedown.prevent="selectThaiAddress(result)"
              >
                <span class="font-medium">{{ result.subdistrict }}</span>
                <span class="text-n-slate-10"
                  >, {{ result.district }}, {{ result.province }}
                  {{ result.postal_code }}</span
                >
              </li>
            </ul>
          </div>
          <div>
            <label class="text-xs font-medium text-n-slate-11">
              {{ t(`${I18N}.FIELD_PROVINCE`) }}
            </label>
            <input
              :value="addressForm.state"
              class="w-full text-sm border border-n-slate-6 rounded-md px-3 py-1.5 mt-0.5"
              @input="updateField('state', $event.target.value)"
            />
          </div>
        </div>

        <!-- Postal Code -->
        <div class="w-1/3 relative">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t(`${I18N}.FIELD_POSTAL`) }}
          </label>
          <input
            :value="addressForm.pincode"
            class="w-full text-sm border border-n-slate-6 rounded-md px-3 py-1.5 mt-0.5"
            @input="onPostalInput($event.target.value)"
          />
          <!-- Thai address autocomplete dropdown (Postal) -->
          <ul
            v-if="showAutocomplete && autocompleteField === 'pincode'"
            class="absolute z-10 mt-1 w-full min-w-[280px] max-h-[160px] overflow-y-auto bg-white dark:bg-n-slate-2 border border-n-slate-6 rounded-md shadow-lg"
          >
            <li
              v-for="(result, idx) in autocompleteResults"
              :key="idx"
              class="px-3 py-1.5 text-sm text-n-slate-12 hover:bg-n-blue-2 cursor-pointer"
              @mousedown.prevent="selectThaiAddress(result)"
            >
              <span class="font-medium">{{ result.postal_code }}</span>
              <span class="text-n-slate-10">
                — {{ result.subdistrict }}, {{ result.district }},
                {{ result.province }}</span
              >
            </li>
          </ul>
        </div>

        <!-- Register checkbox (State B only — LINE customer not yet member) -->
        <label
          v-if="lookupState === 'new_customer'"
          class="flex items-center gap-2 mt-3 cursor-pointer"
          :aria-label="t(`${I18N}.REGISTER_MEMBER`)"
        >
          <input
            type="checkbox"
            :checked="registerCustomer"
            class="rounded"
            @change="emit('update:register-customer', $event.target.checked)"
          />
          <span class="text-sm text-n-slate-11">
            {{ t(`${I18N}.REGISTER_MEMBER`) }}
          </span>
        </label>
      </div>
    </div>
  </div>
</template>
