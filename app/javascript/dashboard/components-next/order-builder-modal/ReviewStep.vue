<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { formatPrice } from './formatPrice';

const props = defineProps({
  items: { type: Array, default: () => [] },
  resolvedAddress: { type: Object, default: null },
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
  grandTotal: { type: String, default: '' },
  sendState: {
    type: String,
    default: 'idle',
    validator: v => ['idle', 'sending', 'success', 'error'].includes(v),
  },
  sendError: { type: String, default: '' },
});

const emit = defineEmits(['send', 'back']);

const { t } = useI18n();
const I18N = 'CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL';

// Address display
const addressLines = computed(() => {
  if (props.resolvedAddress) {
    const a = props.resolvedAddress;
    return [
      a.address_title || a.name,
      a.phone,
      a.address_line1,
      [a.city, a.state, a.pincode].filter(Boolean).join(', '),
    ].filter(Boolean);
  }
  const f = props.addressForm;
  return [
    f.name,
    f.phone,
    f.address_line1,
    [f.city, f.state, f.pincode].filter(Boolean).join(', '),
    f.notes ? t(`${I18N}.NOTES_PREFIX`, { notes: f.notes }) : null,
  ].filter(Boolean);
});

const isSendDisabled = computed(
  () => props.sendState === 'sending' || props.sendState === 'success'
);
</script>

<template>
  <div class="flex flex-col p-6">
    <!-- Back link -->
    <button
      class="mb-4 flex items-center gap-1 self-start text-sm text-n-blue-11 transition-colors hover:text-n-blue-12"
      @click="emit('back')"
    >
      <Icon icon="i-lucide-arrow-left" size="14" />
      {{ t(`${I18N}.BACK_DELIVERY`) }}
    </button>

    <!-- Review content (hidden during success — overlay in parent handles it) -->
    <template v-if="sendState !== 'success'">
      <!-- Heading -->
      <h3 class="mb-4 text-lg font-semibold text-n-slate-12">
        {{ t(`${I18N}.REVIEW_TITLE`) }}
      </h3>

      <!-- Error banner -->
      <div
        v-if="sendState === 'error'"
        class="mb-4 flex items-center gap-2 rounded-lg border border-n-ruby-6 bg-n-ruby-3 px-4 py-3"
      >
        <Icon
          icon="i-lucide-alert-circle"
          size="16"
          class="shrink-0 text-n-ruby-11"
        />
        <p class="flex-1 text-sm text-n-ruby-11">
          {{ t(`${I18N}.SEND_ERROR`, { error: sendError }) }}
        </p>
        <button
          class="shrink-0 text-sm font-semibold text-n-ruby-11 transition-colors hover:text-n-ruby-12"
          @click="emit('send')"
        >
          {{ t(`${I18N}.SEND_RETRY`) }}
        </button>
      </div>

      <!-- Items heading -->
      <h4
        class="mb-2 text-xs font-semibold uppercase tracking-wide text-n-slate-9"
      >
        {{ t(`${I18N}.REVIEW_ITEMS_HEADING`) }}
      </h4>

      <!-- Item list -->
      <div class="mb-4 flex flex-col gap-2">
        <div
          v-for="item in items"
          :key="item.item_code"
          class="flex items-center gap-3 rounded-lg bg-n-slate-2 px-3 py-2"
        >
          <!-- Thumbnail -->
          <div
            class="h-10 w-10 shrink-0 overflow-hidden rounded-md bg-n-slate-3"
          >
            <img
              v-if="item.image_url"
              :src="item.image_url"
              :alt="item.item_name"
              class="h-full w-full object-cover"
            />
            <div v-else class="flex h-full w-full items-center justify-center">
              <Icon icon="i-lucide-package" size="16" class="text-n-slate-9" />
            </div>
          </div>
          <!-- Name + qty -->
          <div class="flex-1 min-w-0">
            <p class="truncate text-sm font-medium text-n-slate-12">
              {{ item.item_name }}
            </p>
            <p class="text-xs text-n-slate-10">
              {{ item.qty }} {{ t(`${I18N}.QTY_TIMES`) }}
              {{ formatPrice(item.price, item.currency || 'THB') }}
            </p>
          </div>
          <!-- Line total -->
          <span class="shrink-0 text-sm font-semibold text-n-slate-12">
            {{ formatPrice(item.price * item.qty, item.currency || 'THB') }}
          </span>
        </div>
      </div>

      <!-- Divider -->
      <div class="mb-4 border-t border-n-weak" />

      <!-- Delivery address -->
      <h4
        class="mb-2 text-xs font-semibold uppercase tracking-wide text-n-slate-9"
      >
        {{ t(`${I18N}.REVIEW_DELIVERY_HEADING`) }}
      </h4>
      <div class="mb-4 rounded-lg border border-n-weak px-4 py-3">
        <p
          v-for="(line, idx) in addressLines"
          :key="idx"
          class="text-sm"
          :class="idx === 0 ? 'font-medium text-n-slate-12' : 'text-n-slate-10'"
        >
          {{ line }}
        </p>
      </div>

      <!-- Divider -->
      <div class="mb-4 border-t border-n-weak" />

      <!-- Grand total -->
      <div class="mb-6 flex items-center justify-between">
        <span class="text-base font-semibold text-n-slate-12">
          {{ t(`${I18N}.REVIEW_TOTAL`) }}
        </span>
        <span class="text-xl font-bold text-n-slate-12">
          {{ grandTotal }}
        </span>
      </div>

      <!-- Send button -->
      <button
        class="flex w-full items-center justify-center gap-2 rounded-lg px-4 py-3 text-sm font-semibold transition-colors"
        :class="
          !isSendDisabled
            ? 'bg-n-blue-9 text-white hover:bg-n-blue-10'
            : 'cursor-not-allowed bg-n-slate-3 text-n-slate-9'
        "
        :disabled="isSendDisabled"
        @click="emit('send')"
      >
        <Spinner v-if="sendState === 'sending'" :size="16" />
        <span>
          {{
            sendState === 'sending'
              ? t(`${I18N}.SENDING_CHECKOUT`)
              : t(`${I18N}.SEND_CHECKOUT`)
          }}
        </span>
      </button>
    </template>
  </div>
</template>
