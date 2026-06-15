<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import HistoryCard from 'dashboard/components-next/captain/assistant/HistoryCard.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import CaptainResponseHistoryAPI from 'dashboard/api/captain/responseHistory';

const route = useRoute();
const { t } = useI18n();

const selectedAssistantId = computed(() => Number(route.params.assistantId));

// Data state
const responses = ref([]);
const totalCount = ref(0);
const currentPage = ref(1);
const isFetching = ref(false);
const fetchError = ref(false);

// Search state
const searchQuery = ref('');

const hasActiveSearch = computed(() => searchQuery.value.trim().length > 0);

const fetchResponses = async () => {
  isFetching.value = true;
  fetchError.value = false;
  try {
    const { data } = await CaptainResponseHistoryAPI.get({
      page: currentPage.value,
      assistantId: selectedAssistantId.value,
      search: searchQuery.value || undefined,
    });
    responses.value = data.payload || [];
    totalCount.value = data.meta?.total_count ?? 0;
  } catch {
    fetchError.value = true;
  } finally {
    isFetching.value = false;
  }
};

const debouncedFetch = debounce(() => {
  currentPage.value = 1;
  fetchResponses();
}, 300);

const handleSearchInput = event => {
  searchQuery.value = event.target.value;
  debouncedFetch();
};

const handleClearSearch = () => {
  searchQuery.value = '';
  currentPage.value = 1;
  fetchResponses();
};

const handleRetry = () => {
  fetchResponses();
};

const handlePageChange = page => {
  currentPage.value = page;
  fetchResponses();
};

onMounted(() => {
  fetchResponses();
});
</script>

<template>
  <PageLayout
    :header-title="t('CAPTAIN_HISTORY.HEADER')"
    :total-count="totalCount"
    :current-page="currentPage"
    :show-pagination-footer="!isFetching && !fetchError && !!responses.length"
    :is-fetching="isFetching"
    :is-empty="fetchError || !responses.length"
    :show-know-more="false"
    feature-flag="captain"
    @update:current-page="handlePageChange"
  >
    <template #search>
      <template v-if="!fetchError && (responses.length || hasActiveSearch)">
        <Input
          :model-value="searchQuery"
          :placeholder="t('CAPTAIN_HISTORY.SEARCH.PLACEHOLDER')"
          icon="i-lucide-search"
          @input="handleSearchInput"
        />
      </template>
    </template>

    <template #emptyState>
      <div
        v-if="fetchError"
        class="flex flex-col items-center justify-center py-16 text-center"
      >
        <span class="i-lucide-alert-circle text-3xl text-n-slate-8 mb-3" />
        <h3 class="text-base font-medium text-n-slate-12 mb-1">
          {{ t('CAPTAIN_HISTORY.SEARCH.ERROR_TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11 mb-4">
          {{ t('CAPTAIN_HISTORY.SEARCH.ERROR_SUBTITLE') }}
        </p>
        <Button
          :label="t('CAPTAIN_HISTORY.SEARCH.RETRY')"
          size="sm"
          @click="handleRetry"
        />
      </div>
      <div
        v-else-if="hasActiveSearch"
        class="flex flex-col items-center justify-center py-16 text-center"
      >
        <span class="i-lucide-search text-3xl text-n-slate-8 mb-3" />
        <h3 class="text-base font-medium text-n-slate-12 mb-1">
          {{ t('CAPTAIN_HISTORY.SEARCH.NO_RESULTS_TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11 mb-4">
          {{ t('CAPTAIN_HISTORY.SEARCH.NO_RESULTS_SUBTITLE') }}
        </p>
        <button
          class="text-sm font-medium text-b-600 hover:text-b-700"
          @click="handleClearSearch"
        >
          {{ t('CAPTAIN_HISTORY.SEARCH.CLEAR_SEARCH') }}
        </button>
      </div>
      <div
        v-else
        class="flex flex-col items-center justify-center py-16 text-center"
      >
        <span class="i-lucide-history text-3xl text-n-slate-8 mb-3" />
        <h3 class="text-base font-medium text-n-slate-12 mb-1">
          {{ t('CAPTAIN_HISTORY.EMPTY.TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11 mb-4">
          {{ t('CAPTAIN_HISTORY.EMPTY.SUBTITLE') }}
        </p>
      </div>
    </template>

    <template #paywall>
      <CaptainPaywall />
    </template>

    <template #body>
      <div class="flex flex-col gap-4 pb-16">
        <HistoryCard
          v-for="response in responses"
          :key="response.id"
          :content="response.content"
          :conversation-display-id="response.conversation_display_id"
          :created-at="response.created_at"
          :approved-by="response.approved_by"
          :edited="response.edited"
          :model="response.model"
          :input-tokens="response.input_tokens"
          :output-tokens="response.output_tokens"
        />
      </div>
    </template>
  </PageLayout>
</template>
