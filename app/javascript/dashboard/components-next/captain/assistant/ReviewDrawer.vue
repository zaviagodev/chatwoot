<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import StarRatingInput from './StarRatingInput.vue';
import PhotoUploadZone from './PhotoUploadZone.vue';
import TagChipInput from './TagChipInput.vue';
import ProductSearchSelect from './ProductSearchSelect.vue';

const props = defineProps({
  isOpen: { type: Boolean, default: false },
  review: { type: Object, default: null },
  assistantId: { type: Number, required: true },
});

const emit = defineEmits(['close', 'saved']);
const store = useStore();
const { t } = useI18n();

const isEditing = computed(() => !!props.review);
const title = computed(() =>
  isEditing.value
    ? t('CAPTAIN_REVIEWS.DRAWER.EDIT_TITLE')
    : t('CAPTAIN_REVIEWS.DRAWER.ADD_TITLE')
);

// Form state
const reviewerName = ref('');
const rating = ref(0);
const reviewText = ref('');
const categoryTags = ref([]);
const productId = ref(null);
const photoData = ref({
  newFiles: [],
  existingPhotos: [],
  removedSignedIds: [],
});
const isSaving = ref(false);

// Discard dialog
const discardDialogRef = ref(null);

const isDirty = computed(() => {
  if (!isEditing.value) {
    return (
      reviewerName.value ||
      rating.value > 0 ||
      reviewText.value ||
      categoryTags.value.length > 0 ||
      productId.value !== null ||
      photoData.value.newFiles.length > 0
    );
  }
  const r = props.review;
  return (
    reviewerName.value !== (r.reviewer_name || '') ||
    rating.value !== (r.rating || 0) ||
    reviewText.value !== (r.review_text || '') ||
    JSON.stringify(categoryTags.value) !==
      JSON.stringify(r.category_tags || []) ||
    productId.value !== (r.captain_product_id || null) ||
    photoData.value.newFiles.length > 0 ||
    photoData.value.removedSignedIds.length > 0
  );
});

const canSave = computed(() => {
  const hasExistingPhotos = isEditing.value
    ? photoData.value.existingPhotos.length -
        photoData.value.removedSignedIds.length >
      0
    : false;
  return (
    reviewText.value.trim() ||
    photoData.value.newFiles.length > 0 ||
    hasExistingPhotos
  );
});

const textCharCount = computed(() => reviewText.value.length);

// Reset form when drawer opens or review changes
watch(
  () => [props.isOpen, props.review],
  () => {
    if (props.isOpen) {
      if (props.review) {
        reviewerName.value = props.review.reviewer_name || '';
        rating.value = props.review.rating || 0;
        reviewText.value = props.review.review_text || '';
        categoryTags.value = [...(props.review.category_tags || [])];
        productId.value = props.review.captain_product_id || null;
        photoData.value = {
          newFiles: [],
          existingPhotos: [...(props.review.photos || [])],
          removedSignedIds: [],
        };
      } else {
        reviewerName.value = '';
        rating.value = 0;
        reviewText.value = '';
        categoryTags.value = [];
        productId.value = null;
        photoData.value = {
          newFiles: [],
          existingPhotos: [],
          removedSignedIds: [],
        };
      }
    }
  },
  { immediate: true }
);

const handleClose = () => {
  if (isDirty.value) {
    discardDialogRef.value?.open();
  } else {
    emit('close');
  }
};

const handleDiscard = () => {
  emit('close');
};

const handleSave = async () => {
  isSaving.value = true;
  try {
    const payload = {
      assistantId: props.assistantId,
      reviewer_name: reviewerName.value || null,
      rating: rating.value || null,
      review_text: reviewText.value || null,
      category_tags: categoryTags.value,
      captain_product_id: productId.value || null,
      photos: photoData.value.newFiles,
      removed_photo_signed_ids: photoData.value.removedSignedIds,
    };

    if (isEditing.value) {
      payload.id = props.review.id;
      await store.dispatch('captainReviews/update', payload);
      useAlert(t('CAPTAIN_REVIEWS.TOAST.UPDATE_SUCCESS'));
    } else {
      await store.dispatch('captainReviews/create', payload);
      useAlert(t('CAPTAIN_REVIEWS.TOAST.CREATE_SUCCESS'));
    }
    emit('saved');
  } catch {
    useAlert(
      isEditing.value
        ? t('CAPTAIN_REVIEWS.TOAST.UPDATE_ERROR')
        : t('CAPTAIN_REVIEWS.TOAST.CREATE_ERROR')
    );
  }
  isSaving.value = false;
};

const handleKeydown = event => {
  if (event.key === 'Escape') {
    handleClose();
  }
};
</script>

<template>
  <Teleport to="body">
    <Transition name="slide">
      <div
        v-if="isOpen"
        class="fixed inset-0 z-50 flex justify-end"
        @keydown="handleKeydown"
      >
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-black/30" @click="handleClose" />

        <!-- Drawer panel -->
        <div
          class="relative w-[40vw] min-w-[400px] max-w-[600px] bg-n-surface-1 shadow-xl flex flex-col overflow-hidden"
        >
          <!-- Header -->
          <div
            class="flex items-center justify-between px-6 py-4 border-b border-n-slate-3"
          >
            <h2 class="text-base font-semibold text-n-slate-12">
              {{ title }}
            </h2>
            <button
              class="p-1 rounded hover:bg-n-slate-3 text-n-slate-9"
              @click="handleClose"
            >
              <span class="i-lucide-x text-lg" />
            </button>
          </div>

          <!-- Body -->
          <div class="flex-1 overflow-y-auto px-6 py-5 space-y-6">
            <!-- Section 1: Review Details -->
            <div class="space-y-4">
              <h3 class="text-sm font-medium text-n-slate-12">
                {{ t('CAPTAIN_REVIEWS.DRAWER.REVIEWER_NAME') }}
              </h3>
              <Input
                v-model="reviewerName"
                :placeholder="
                  t('CAPTAIN_REVIEWS.DRAWER.REVIEWER_NAME_PLACEHOLDER')
                "
              />

              <div>
                <label class="text-sm font-medium text-n-slate-12 block mb-2">
                  {{ t('CAPTAIN_REVIEWS.DRAWER.RATING') }}
                </label>
                <StarRatingInput v-model="rating" />
              </div>

              <div>
                <label class="text-sm font-medium text-n-slate-12 block mb-2">
                  {{ t('CAPTAIN_REVIEWS.DRAWER.REVIEW_TEXT') }}
                </label>
                <textarea
                  v-model="reviewText"
                  :placeholder="
                    t('CAPTAIN_REVIEWS.DRAWER.REVIEW_TEXT_PLACEHOLDER')
                  "
                  rows="4"
                  maxlength="500"
                  class="w-full px-3 py-2 text-sm border rounded-lg border-n-slate-5 bg-n-surface-1 text-n-slate-12 placeholder:text-n-slate-8 focus:border-b-500 focus:ring-1 focus:ring-b-500 outline-none resize-none"
                />
                <span class="text-xs text-n-slate-8 mt-1 block text-right">
                  {{
                    t('CAPTAIN_REVIEWS.DRAWER.CHAR_COUNT', {
                      current: textCharCount,
                      max: 500,
                    })
                  }}
                </span>
              </div>
            </div>

            <!-- Section 2: Photos -->
            <div>
              <h3 class="text-sm font-medium text-n-slate-12 mb-3">
                {{ t('CAPTAIN_REVIEWS.DRAWER.PHOTOS') }}
              </h3>
              <PhotoUploadZone v-model="photoData" />
            </div>

            <!-- Section 3: Categorise -->
            <div>
              <h3 class="text-sm font-medium text-n-slate-12 mb-3">
                {{ t('CAPTAIN_REVIEWS.DRAWER.CATEGORIES') }}
              </h3>
              <TagChipInput
                v-model="categoryTags"
                :placeholder="
                  t('CAPTAIN_REVIEWS.DRAWER.CATEGORIES_PLACEHOLDER')
                "
              />

              <!-- Product link -->
              <div class="mt-4">
                <label class="text-sm font-medium text-n-slate-11 block mb-2">
                  {{ t('CAPTAIN_REVIEWS.DRAWER.PRODUCT_LINK') }}
                </label>
                <ProductSearchSelect
                  v-model="productId"
                  :assistant-id="assistantId"
                  :disabled="isSaving"
                />
              </div>
            </div>
          </div>

          <!-- Footer -->
          <div
            class="px-6 py-4 border-t border-n-slate-3 flex justify-end gap-3"
          >
            <Button
              :label="t('CAPTAIN_REVIEWS.DRAWER.CANCEL')"
              color="slate"
              variant="faded"
              @click="handleClose"
            />
            <Button
              :label="t('CAPTAIN_REVIEWS.DRAWER.SAVE')"
              :disabled="!canSave || isSaving"
              :is-loading="isSaving"
              @click="handleSave"
            />
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>

  <!-- Discard confirmation dialog -->
  <Dialog
    ref="discardDialogRef"
    type="alert"
    :title="t('CAPTAIN_REVIEWS.DRAWER.DISCARD_TITLE')"
    :description="t('CAPTAIN_REVIEWS.DRAWER.DISCARD_MESSAGE')"
    :confirm-button-label="t('CAPTAIN_REVIEWS.DRAWER.DISCARD_CONFIRM')"
    @confirm="handleDiscard"
  />
</template>

<style scoped>
.slide-enter-active,
.slide-leave-active {
  transition: all 0.3s ease;
}

.slide-enter-from .relative,
.slide-leave-to .relative {
  transform: translateX(100%);
}

.slide-enter-from .absolute,
.slide-leave-to .absolute {
  opacity: 0;
}
</style>
