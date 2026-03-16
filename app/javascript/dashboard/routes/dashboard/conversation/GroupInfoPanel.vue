<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';

const props = defineProps({
  conversation: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();

const groupName = computed(
  () =>
    props.conversation?.group_name ||
    props.conversation?.additional_attributes?.group_name ||
    'LINE Group'
);

const groupIcon = computed(
  () =>
    props.conversation?.group_icon_url ||
    props.conversation?.additional_attributes?.group_icon_url ||
    ''
);

const memberCount = computed(() => props.conversation?.group_member_count || 0);
</script>

<template>
  <div class="px-4 py-3 border-b border-n-weak">
    <div class="flex items-center gap-3">
      <Avatar :name="groupName" :src="groupIcon" :size="48" rounded-full />
      <div class="flex flex-col min-w-0">
        <h3 class="text-sm font-semibold text-n-slate-12 truncate">
          {{ groupName }}
        </h3>
        <span class="text-xs text-n-slate-10">
          {{
            t('CONVERSATION.SIDEBAR.GROUP_MEMBER_COUNT', { count: memberCount })
          }}
        </span>
      </div>
    </div>
  </div>
</template>
