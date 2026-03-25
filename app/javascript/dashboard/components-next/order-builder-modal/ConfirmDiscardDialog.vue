<script setup>
import { watchEffect, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
});

const emit = defineEmits(['discard', 'keepEditing']);

const { t } = useI18n();
const I18N = 'CONVERSATION.REPLYBOX.ORDER_BUILDER_MODAL';

// Dialog handles its own Escape key (parent defers when showConfirmDialog is true)
let keydownHandler = null;

watchEffect(() => {
  // Clean up previous listener
  if (keydownHandler) {
    document.removeEventListener('keydown', keydownHandler);
    keydownHandler = null;
  }
  if (props.show) {
    keydownHandler = e => {
      if (e.key === 'Escape') {
        e.stopPropagation();
        emit('keepEditing');
      }
    };
    document.addEventListener('keydown', keydownHandler);
  }
});

onUnmounted(() => {
  if (keydownHandler) {
    document.removeEventListener('keydown', keydownHandler);
  }
});
</script>

<template>
  <TeleportWithDirection to="body">
    <Transition
      enter-active-class="transition-opacity duration-150 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-opacity duration-100 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="show"
        class="fixed inset-0 z-[10000] flex items-center justify-center bg-n-alpha-black1 backdrop-blur-[2px]"
        role="alertdialog"
        aria-modal="true"
        :aria-label="t(`${I18N}.CONFIRM_DISCARD_TITLE`)"
        aria-describedby="confirm-discard-desc"
      >
        <div
          class="w-full max-w-sm rounded-xl bg-n-solid-1 p-6 shadow-xl"
          @click.stop
        >
          <h3 class="mb-2 text-base font-semibold text-n-slate-12">
            {{ t(`${I18N}.CONFIRM_DISCARD_TITLE`) }}
          </h3>
          <p id="confirm-discard-desc" class="mb-6 text-sm text-n-slate-11">
            {{ t(`${I18N}.CONFIRM_DISCARD_MESSAGE`) }}
          </p>
          <div class="flex items-center justify-end gap-3">
            <button
              class="rounded-lg px-4 py-2 text-sm font-semibold text-n-ruby-11 transition-colors hover:bg-n-ruby-3"
              @click="emit('discard')"
            >
              {{ t(`${I18N}.CONFIRM_DISCARD`) }}
            </button>
            <button
              class="rounded-lg bg-n-blue-9 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-n-blue-10"
              @click="emit('keepEditing')"
            >
              {{ t(`${I18N}.CONFIRM_KEEP`) }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </TeleportWithDirection>
</template>
