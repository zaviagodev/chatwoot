<script setup>
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  hasErpConnection: {
    type: Boolean,
    default: false,
  },
});

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
          v-if="hasErpConnection"
          :label="$t('CAPTAIN_PRODUCTS.EMPTY_STATE.ADD_FROM_ERP')"
          icon="i-lucide-refresh-cw"
          @click="emit('addFromErp')"
        />
        <Button
          :label="$t('CAPTAIN_PRODUCTS.EMPTY_STATE.ADD_MANUALLY')"
          icon="i-lucide-plus"
          :variant="hasErpConnection ? 'faded' : undefined"
          :color="hasErpConnection ? 'slate' : undefined"
          @click="emit('addManually')"
        />
      </div>
    </template>
  </EmptyStateLayout>
</template>
