<script setup>
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { computed, onMounted, ref, defineOptions } from 'vue';
import { useRouter } from 'vue-router';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CardDesignCard from './CardDesignCard.vue';

defineOptions({ name: 'CardDesignsIndex' });

const store = useStore();
const storeGetters = useStoreGetters();
const router = useRouter();
const { t } = useI18n();

const showDeleteConfirmation = ref(false);
const activeDesign = ref(null);

const records = computed(() => storeGetters.getCardDesigns.value);
const uiFlags = computed(() => storeGetters.getCardDesignUIFlags.value);

const deleteMessage = computed(() => {
  if (!activeDesign.value) return '';
  const count = activeDesign.value.usage_count || 0;
  return t('CARD_DESIGNS.DELETE_MODAL.MESSAGE', {
    name: activeDesign.value.name,
    count,
  });
});

onMounted(() => {
  store.dispatch('getCardDesigns');
});

const navigateToNew = () => {
  router.push({ name: 'card_designs_new' });
};

const navigateToEdit = designId => {
  router.push({ name: 'card_designs_edit', params: { designId } });
};

const handleEdit = async design => {
  if (design.is_builtin) {
    try {
      const copy = await store.dispatch('duplicateCardDesign', design.id);
      if (copy?.id) {
        useAlert(t('CARD_DESIGNS.CREATED_COPY', { name: copy.name }));
        navigateToEdit(copy.id);
      }
    } catch (error) {
      useAlert(error?.message || t('CARD_DESIGNS.COPY_FAILED'));
    }
  } else {
    navigateToEdit(design.id);
  }
};

const handleDuplicate = async design => {
  try {
    const copy = await store.dispatch('duplicateCardDesign', design.id);
    if (copy?.id) {
      useAlert(t('CARD_DESIGNS.DUPLICATED', { name: copy.name }));
    }
  } catch (error) {
    useAlert(error?.message || t('CARD_DESIGNS.DUPLICATE_FAILED'));
  }
};

const handleSetDefault = async design => {
  try {
    await store.dispatch('setDefaultCardDesign', design.id);
    useAlert(t('CARD_DESIGNS.SET_DEFAULT', { name: design.name }));
  } catch (error) {
    useAlert(error?.message || t('CARD_DESIGNS.SET_DEFAULT_FAILED'));
  }
};

const openDeletePopup = design => {
  activeDesign.value = design;
  showDeleteConfirmation.value = true;
};

const closeDeletePopup = () => {
  showDeleteConfirmation.value = false;
  activeDesign.value = null;
};

const confirmDeletion = async () => {
  if (!activeDesign.value) return;
  try {
    await store.dispatch('deleteCardDesign', activeDesign.value.id);
    useAlert(t('CARD_DESIGNS.DELETED'));
  } catch (error) {
    useAlert(error?.message || t('CARD_DESIGNS.DELETE_FAILED'));
  }
  closeDeletePopup();
};
</script>

<template>
  <div class="flex-1 overflow-auto">
    <BaseSettingsHeader
      :title="t('CARD_DESIGNS.HEADER.TITLE')"
      :description="t('CARD_DESIGNS.HEADER.DESCRIPTION')"
      feature-name="card_designs"
    >
      <template #actions>
        <Button
          icon="i-lucide-circle-plus"
          :label="t('CARD_DESIGNS.NEW_DESIGN')"
          @click="navigateToNew"
        />
      </template>
    </BaseSettingsHeader>

    <div class="mt-6 flex-1">
      <woot-loading-state
        v-if="uiFlags.fetchingList"
        :message="t('CARD_DESIGNS.LOADING')"
      />
      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <CardDesignCard
          v-for="design in records"
          :key="design.id"
          :design="design"
          @edit="handleEdit"
          @duplicate="handleDuplicate"
          @set-default="handleSetDefault"
          @delete="openDeletePopup"
        />
      </div>
    </div>

    <woot-delete-modal
      v-model:show="showDeleteConfirmation"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="t('CARD_DESIGNS.DELETE_MODAL.TITLE')"
      :message="deleteMessage"
      :confirm-text="t('CARD_DESIGNS.DELETE_MODAL.CONFIRM')"
      :reject-text="t('CARD_DESIGNS.DELETE_MODAL.REJECT')"
    />
  </div>
</template>
