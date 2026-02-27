<script setup>
import { computed, onMounted, ref } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import ReviewCard from 'dashboard/components-next/captain/assistant/ReviewCard.vue';
import ReviewDrawer from 'dashboard/components-next/captain/assistant/ReviewDrawer.vue';
import BulkSelectBar from 'dashboard/components-next/captain/assistant/BulkSelectBar.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import CaptainReviews from 'dashboard/api/captain/reviews';

const route = useRoute();
const store = useStore();
const { t } = useI18n();

const uiFlags = useMapGetter('captainReviews/getUIFlags');
const reviews = useMapGetter('captainReviews/getRecords');
const reviewsMeta = useMapGetter('captainReviews/getMeta');

const isFetching = computed(() => uiFlags.value.fetchingList);
const selectedAssistantId = computed(() => Number(route.params.assistantId));

// Search state
const searchQuery = ref('');
const fetchError = ref(false);

// Category filter state
const selectedCategory = ref('');
const categories = ref([]);

// Drawer state
const isDrawerOpen = ref(false);
const editingReview = ref(null);

// Bulk selection state
const selectedIds = ref(new Set());

// Delete confirm state
const deleteConfirmDialogRef = ref(null);
const deletingReviewId = ref(null);

// Bulk delete confirm state
const bulkDeleteDialogRef = ref(null);

// Pagination
const currentPage = ref(1);
const totalCount = computed(() => reviewsMeta.value?.totalCount ?? 0);

const hasActiveSearch = computed(
  () => searchQuery.value.trim().length > 0 || selectedCategory.value !== ''
);

const bulkSelectAllLabel = computed(() =>
  t('CAPTAIN_REVIEWS.BULK.SELECT_ALL', { count: reviews.value.length })
);
const bulkSelectedCountLabel = computed(() =>
  t('CAPTAIN_REVIEWS.BULK.SELECTED', { count: selectedIds.value.size })
);

const fetchReviews = async () => {
  fetchError.value = false;
  try {
    await store.dispatch('captainReviews/get', {
      page: currentPage.value,
      assistantId: selectedAssistantId.value,
      search: searchQuery.value || undefined,
      category: selectedCategory.value || undefined,
    });
  } catch {
    fetchError.value = true;
  }
};

const fetchCategories = async () => {
  try {
    const { data } = await CaptainReviews.getDistinctCategories({
      assistantId: selectedAssistantId.value,
    });
    categories.value = data.categories || [];
  } catch {
    categories.value = [];
  }
};

const clearSelection = () => {
  selectedIds.value = new Set();
};

const debouncedFetch = debounce(() => {
  currentPage.value = 1;
  clearSelection();
  fetchReviews();
}, 300);

const handleSearchInput = event => {
  searchQuery.value = event.target.value;
  debouncedFetch();
};

const handleFilterChange = () => {
  clearSelection();
  currentPage.value = 1;
  fetchReviews();
};

const handleClearSearch = () => {
  searchQuery.value = '';
  selectedCategory.value = '';
  currentPage.value = 1;
  clearSelection();
  fetchReviews();
};

const handleRetry = () => {
  fetchReviews();
};

const handlePageChange = page => {
  currentPage.value = page;
  clearSelection();
  fetchReviews();
};

const handleOpenDrawer = (review = null) => {
  editingReview.value = review;
  isDrawerOpen.value = true;
};

const handleCloseDrawer = () => {
  isDrawerOpen.value = false;
  editingReview.value = null;
};

const handleDrawerSaved = () => {
  handleCloseDrawer();
  fetchReviews();
  fetchCategories();
};

const handleAction = ({ action, id }) => {
  const review = reviews.value.find(r => r.id === id);
  if (!review) return;

  if (action === 'edit') {
    handleOpenDrawer(review);
  } else if (action === 'delete') {
    deletingReviewId.value = id;
    deleteConfirmDialogRef.value?.open();
  }
};

const handleDeleteConfirm = async () => {
  if (!deletingReviewId.value) return;
  try {
    await store.dispatch('captainReviews/delete', {
      id: deletingReviewId.value,
      assistantId: selectedAssistantId.value,
    });
    useAlert(t('CAPTAIN_REVIEWS.TOAST.DELETE_SUCCESS'));
    if (reviews.value.length === 0 && currentPage.value > 1) {
      currentPage.value -= 1;
    }
    fetchReviews();
    fetchCategories();
  } catch {
    useAlert(t('CAPTAIN_REVIEWS.TOAST.DELETE_ERROR'));
  }
  deletingReviewId.value = null;
};

const handleToggleSelect = id => {
  const selected = new Set(selectedIds.value);
  if (selected.has(id)) {
    selected.delete(id);
  } else {
    selected.add(id);
  }
  selectedIds.value = selected;
};

const handleBulkDeleteClick = () => {
  bulkDeleteDialogRef.value?.open();
};

const handleBulkDelete = async () => {
  const ids = [...selectedIds.value];
  try {
    await CaptainReviews.bulkDelete({
      assistantId: selectedAssistantId.value,
      ids,
    });
    clearSelection();
    fetchReviews();
    fetchCategories();
    useAlert(
      t('CAPTAIN_REVIEWS.TOAST.BULK_DELETE_SUCCESS', { count: ids.length })
    );
  } catch {
    useAlert(t('CAPTAIN_REVIEWS.TOAST.DELETE_ERROR'));
  }
};

onMounted(() => {
  fetchReviews();
  fetchCategories();
});
</script>

<template>
  <PageLayout
    :header-title="t('CAPTAIN_REVIEWS.HEADER')"
    :button-label="t('CAPTAIN_REVIEWS.ADD_NEW')"
    :button-policy="['administrator']"
    :total-count="totalCount"
    :current-page="currentPage"
    :show-pagination-footer="!isFetching && !fetchError && !!reviews.length"
    :is-fetching="isFetching"
    :is-empty="fetchError || !reviews.length"
    :show-know-more="false"
    feature-flag="captain"
    @update:current-page="handlePageChange"
    @click="handleOpenDrawer()"
  >
    <template #search>
      <template v-if="!fetchError && (reviews.length || hasActiveSearch)">
        <Input
          :model-value="searchQuery"
          :placeholder="t('CAPTAIN_REVIEWS.SEARCH.PLACEHOLDER')"
          icon="i-lucide-search"
          @input="handleSearchInput"
        />
        <select
          v-if="categories.length >= 2"
          v-model="selectedCategory"
          class="px-3 py-2 text-sm rounded-lg border bg-n-alpha-1 border-n-weak text-n-slate-12"
          @change="handleFilterChange"
        >
          <option value="">
            {{ t('CAPTAIN_REVIEWS.SEARCH.ALL_CATEGORIES') }}
          </option>
          <option v-for="cat in categories" :key="cat" :value="cat">
            {{ cat }}
          </option>
        </select>
      </template>
    </template>

    <template #emptyState>
      <div
        v-if="fetchError"
        class="flex flex-col items-center justify-center py-16 text-center"
      >
        <span class="i-lucide-alert-circle text-3xl text-n-slate-8 mb-3" />
        <h3 class="text-base font-medium text-n-slate-12 mb-1">
          {{ t('CAPTAIN_REVIEWS.SEARCH.ERROR_TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11 mb-4">
          {{ t('CAPTAIN_REVIEWS.SEARCH.ERROR_SUBTITLE') }}
        </p>
        <Button
          :label="t('CAPTAIN_REVIEWS.SEARCH.RETRY')"
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
          {{ t('CAPTAIN_REVIEWS.SEARCH.NO_RESULTS_TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11 mb-4">
          {{ t('CAPTAIN_REVIEWS.SEARCH.NO_RESULTS_SUBTITLE') }}
        </p>
        <button
          class="text-sm font-medium text-b-600 hover:text-b-700"
          @click="handleClearSearch"
        >
          {{ t('CAPTAIN_REVIEWS.SEARCH.CLEAR_SEARCH') }}
        </button>
      </div>
      <div
        v-else
        class="flex flex-col items-center justify-center py-16 text-center"
      >
        <span class="i-lucide-star text-3xl text-n-slate-8 mb-3" />
        <h3 class="text-base font-medium text-n-slate-12 mb-1">
          {{ t('CAPTAIN_REVIEWS.EMPTY.TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11 mb-4">
          {{ t('CAPTAIN_REVIEWS.EMPTY.SUBTITLE') }}
        </p>
        <Button
          :label="t('CAPTAIN_REVIEWS.ADD_NEW')"
          size="sm"
          @click="handleOpenDrawer()"
        />
      </div>
    </template>

    <template #paywall>
      <CaptainPaywall />
    </template>

    <template #body>
      <div class="flex flex-col gap-4 pb-16">
        <ReviewCard
          v-for="review in reviews"
          :id="review.id"
          :key="review.id"
          :reviewer-name="review.reviewer_name"
          :rating="review.rating"
          :review-text="review.review_text"
          :category-tags="review.category_tags"
          :photo-urls="review.photo_urls"
          :product-name="review.product_name"
          :selected="selectedIds.has(review.id)"
          @action="handleAction"
          @select="handleToggleSelect(review.id)"
        />
      </div>

      <div
        v-if="selectedIds.size > 0"
        class="fixed bottom-4 left-1/2 -translate-x-1/2 z-50"
      >
        <BulkSelectBar
          v-model="selectedIds"
          :all-items="reviews"
          :select-all-label="bulkSelectAllLabel"
          :selected-count-label="bulkSelectedCountLabel"
        >
          <template #actions>
            <Button
              sm
              faded
              ruby
              icon="i-lucide-trash"
              :label="t('CAPTAIN_REVIEWS.BULK.REMOVE')"
              @click="handleBulkDeleteClick"
            />
          </template>
        </BulkSelectBar>
      </div>
    </template>

    <ReviewDrawer
      :is-open="isDrawerOpen"
      :review="editingReview"
      :assistant-id="selectedAssistantId"
      @close="handleCloseDrawer"
      @saved="handleDrawerSaved"
    />

    <Dialog
      ref="deleteConfirmDialogRef"
      type="alert"
      :title="t('CAPTAIN_REVIEWS.DELETE.TITLE')"
      :description="t('CAPTAIN_REVIEWS.DELETE.MESSAGE')"
      :confirm-button-label="t('CAPTAIN_REVIEWS.DELETE.CONFIRM')"
      @confirm="handleDeleteConfirm"
    />

    <Dialog
      ref="bulkDeleteDialogRef"
      type="alert"
      :title="
        t('CAPTAIN_REVIEWS.BULK.REMOVE_CONFIRM_TITLE', {
          count: selectedIds.size,
        })
      "
      :description="t('CAPTAIN_REVIEWS.BULK.REMOVE_CONFIRM_DESCRIPTION')"
      :confirm-button-label="t('CAPTAIN_REVIEWS.BULK.REMOVE')"
      @confirm="handleBulkDelete"
    />
  </PageLayout>
</template>
