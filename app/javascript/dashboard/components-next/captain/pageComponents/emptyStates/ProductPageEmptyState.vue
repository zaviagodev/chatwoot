<script setup>
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['addFromErp', 'addManually']);
</script>

<template>
  <EmptyStateLayout
    :title="$t('CAPTAIN_PRODUCTS.EMPTY_STATE.TITLE')"
    :subtitle="$t('CAPTAIN_PRODUCTS.EMPTY_STATE.SUBTITLE')"
    :action-perms="['administrator']"
  >
    <template #actions>
      <div class="flex gap-3">
        <Button
          :label="$t('CAPTAIN_PRODUCTS.EMPTY_STATE.ADD_FROM_ERP')"
          icon="i-lucide-refresh-cw"
          @click="emit('addFromErp')"
        />
        <Button
          :label="$t('CAPTAIN_PRODUCTS.EMPTY_STATE.ADD_MANUALLY')"
          icon="i-lucide-plus"
          variant="faded"
          color="slate"
          @click="emit('addManually')"
        />
      </div>
    </template>
  </EmptyStateLayout>
</template>
