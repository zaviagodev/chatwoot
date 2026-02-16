<script setup>
import { computed } from 'vue';
import { useToggle } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Policy from 'dashboard/components/policy.vue';
import { INBOX_TYPES, getInboxIconByType } from 'dashboard/helper/inbox';

const props = defineProps({
  id: {
    type: Number,
    required: true,
  },
  inbox: {
    type: Object,
    required: true,
  },
  assistantId: {
    type: [Number, String],
    required: true,
  },
});

const emit = defineEmits(['action']);

const { t } = useI18n();
const store = useStore();

const [showActionsDropdown, toggleDropdown] = useToggle();

const inboxName = computed(() => {
  const inbox = props.inbox;
  if (!inbox?.name) {
    return '';
  }

  const isTwilioChannel = inbox.channel_type === INBOX_TYPES.TWILIO;
  const isWhatsAppChannel = inbox.channel_type === INBOX_TYPES.WHATSAPP;
  const isEmailChannel = inbox.channel_type === INBOX_TYPES.EMAIL;

  if (isTwilioChannel || isWhatsAppChannel) {
    const identifier = inbox.messaging_service_sid || inbox.phone_number;
    return identifier ? `${inbox.name} (${identifier})` : inbox.name;
  }

  if (isEmailChannel && inbox.email) {
    return `${inbox.name} (${inbox.email})`;
  }

  return inbox.name;
});

const copilotModeOptions = computed(() => [
  { label: t('CAPTAIN.INBOXES.COPILOT_MODE.DRAFT'), value: 'draft' },
  { label: t('CAPTAIN.INBOXES.COPILOT_MODE.AUTO_SEND'), value: 'auto_send' },
  { label: t('CAPTAIN.INBOXES.COPILOT_MODE.OFF'), value: 'off' },
]);

const currentCopilotMode = computed(
  () => props.inbox.copilot_default_mode || 'draft'
);

const copilotModeLabel = computed(() => {
  const option = copilotModeOptions.value.find(
    o => o.value === currentCopilotMode.value
  );
  return option ? option.label : t('CAPTAIN.INBOXES.COPILOT_MODE.DRAFT');
});

const handleCopilotModeChange = async mode => {
  if (mode === currentCopilotMode.value) return;
  try {
    await store.dispatch('captainInboxes/updateCopilotMode', {
      assistantId: props.assistantId,
      inboxId: props.id,
      copilotDefaultMode: mode,
    });
    useAlert(t('CAPTAIN.INBOXES.COPILOT_MODE.SUCCESS_MESSAGE'));
  } catch {
    useAlert(t('CAPTAIN.INBOXES.COPILOT_MODE.ERROR_MESSAGE'));
  }
};

const menuItems = computed(() => [
  {
    label: t('CAPTAIN.INBOXES.OPTIONS.DISCONNECT'),
    value: 'delete',
    action: 'delete',
    icon: 'i-lucide-trash',
  },
]);

const icon = computed(() => {
  const { medium, channel_type: type } = props.inbox;
  return getInboxIconByType(type, medium, 'outline');
});

const handleAction = ({ action, value }) => {
  toggleDropdown(false);
  emit('action', { action, value, id: props.id });
};
</script>

<template>
  <CardLayout>
    <div class="flex justify-between w-full gap-1">
      <span
        class="text-base text-n-slate-12 line-clamp-1 flex items-center gap-2"
      >
        <span :class="icon" />
        {{ inboxName }}
      </span>
      <div class="flex items-center gap-2">
        <SelectMenu
          :options="copilotModeOptions"
          :model-value="currentCopilotMode"
          :label="copilotModeLabel"
          sub-menu-position="bottom"
          @update:model-value="handleCopilotModeChange"
        />
        <Policy
          v-on-clickaway="() => toggleDropdown(false)"
          :permissions="['administrator']"
          class="relative flex items-center group"
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
            class="mt-1 ltr:right-0 rtl:left-0 top-full"
            @action="handleAction($event)"
          />
        </Policy>
      </div>
    </div>
  </CardLayout>
</template>
