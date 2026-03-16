<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import LineFlexPreview from 'dashboard/components-next/card-design/LineFlexPreview.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  design: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['edit', 'duplicate', 'setDefault', 'delete']);
const { t } = useI18n();

const showMenu = ref(false);

const usageText = computed(() => {
  const count = props.design.usage_count || 0;
  if (count === 1) return t('CARD_DESIGNS.CARD.SEND_COUNT_ONE');
  return t('CARD_DESIGNS.CARD.SEND_COUNT', { count });
});

const toggleMenu = () => {
  showMenu.value = !showMenu.value;
};

const closeMenu = () => {
  showMenu.value = false;
};

const handleEdit = () => {
  closeMenu();
  emit('edit', props.design);
};

const handleDuplicate = () => {
  closeMenu();
  emit('duplicate', props.design);
};

const handleSetDefault = () => {
  closeMenu();
  emit('setDefault', props.design);
};

const handleDelete = () => {
  closeMenu();
  emit('delete', props.design);
};
</script>

<template>
  <div
    class="relative rounded-lg border border-n-weak bg-n-solid-1 hover:border-n-slate-8 hover:shadow-sm transition-all"
  >
    <!-- Preview area -->
    <div
      class="flex items-center justify-center p-3 rounded-t-lg overflow-hidden bg-[#7bc67e] min-h-[120px]"
    >
      <LineFlexPreview :design-json="design.design_json" :scale="0.5" />
    </div>

    <!-- Info area -->
    <div class="p-3 border-t border-n-weak">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-1.5 min-w-0">
          <span
            v-if="design.is_default"
            class="i-lucide-star text-n-amber-9 size-3.5 shrink-0"
          />
          <span class="text-sm font-semibold text-n-slate-12 truncate">
            {{ design.name }}
          </span>
        </div>

        <!-- Overflow menu -->
        <div v-on-clickaway="closeMenu" class="relative">
          <Button
            icon="i-lucide-more-horizontal"
            xs
            slate
            faded
            @click="toggleMenu"
          />
          <div
            v-if="showMenu"
            class="absolute right-0 top-8 z-20 w-40 rounded-lg border border-n-weak bg-n-solid-1 shadow-lg py-1"
          >
            <button
              class="w-full px-3 py-1.5 text-left text-sm text-n-slate-12 hover:bg-n-alpha-2"
              @click="handleEdit"
            >
              {{
                design.is_builtin
                  ? t('CARD_DESIGNS.CARD.EDIT_COPY')
                  : t('CARD_DESIGNS.CARD.EDIT')
              }}
            </button>
            <button
              class="w-full px-3 py-1.5 text-left text-sm text-n-slate-12 hover:bg-n-alpha-2"
              @click="handleDuplicate"
            >
              {{ t('CARD_DESIGNS.CARD.DUPLICATE') }}
            </button>
            <button
              v-if="!design.is_default"
              class="w-full px-3 py-1.5 text-left text-sm text-n-slate-12 hover:bg-n-alpha-2"
              @click="handleSetDefault"
            >
              {{ t('CARD_DESIGNS.CARD.SET_AS_DEFAULT') }}
            </button>
            <button
              v-if="!design.is_builtin"
              class="w-full px-3 py-1.5 text-left text-sm text-n-ruby-9 hover:bg-n-alpha-2"
              @click="handleDelete"
            >
              {{ t('CARD_DESIGNS.CARD.DELETE') }}
            </button>
          </div>
        </div>
      </div>

      <!-- Badges -->
      <div class="flex items-center gap-2 mt-1 text-xs text-n-slate-9">
        <span
          v-if="design.is_builtin"
          class="px-1.5 py-0.5 rounded bg-n-alpha-2 text-n-slate-10"
        >
          {{ t('CARD_DESIGNS.CARD.BUILTIN_BADGE') }}
        </span>
        <span>{{ usageText }}</span>
      </div>
    </div>
  </div>
</template>
