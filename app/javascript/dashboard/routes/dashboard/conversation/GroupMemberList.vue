<script setup>
import { computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const store = useStore();
const { t } = useI18n();

const members = computed(() =>
  store.getters['groupContacts/getGroupContacts'](props.conversationId)
);

const isFetching = computed(
  () => store.getters['groupContacts/getUIFlags'].isFetching
);

onMounted(() => {
  store.dispatch('groupContacts/fetch', props.conversationId);
});
</script>

<template>
  <div class="px-2 py-1">
    <div v-if="isFetching" class="flex items-center justify-center py-4">
      <span class="text-xs text-n-slate-10">
        {{ t('CONVERSATION.SIDEBAR.LOADING_MEMBERS') }}
      </span>
    </div>
    <div v-else-if="members.length === 0" class="py-4 text-center">
      <span class="text-xs text-n-slate-10">
        {{ t('CONVERSATION.SIDEBAR.NO_MEMBERS') }}
      </span>
    </div>
    <div v-else class="flex flex-col gap-1 max-h-[200px] overflow-y-auto">
      <div
        v-for="member in members"
        :key="member.id"
        class="flex items-center gap-2 px-2 py-1.5 rounded-lg hover:bg-n-alpha-1 transition-colors"
      >
        <Avatar
          :name="member.name"
          :src="member.thumbnail"
          :size="24"
          rounded-full
        />
        <div class="flex flex-col min-w-0 flex-1">
          <span class="text-sm text-n-slate-12 truncate">
            {{ member.name }}
          </span>
          <span
            v-if="member.phone_number"
            class="text-xs text-n-slate-10 truncate"
          >
            {{ member.phone_number }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
