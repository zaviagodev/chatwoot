<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CaptainResponsesAPI from 'dashboard/api/captain/response';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from 'dashboard/components/Modal.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  questionText: {
    type: String,
    default: '',
  },
  answerText: {
    type: String,
    default: '',
  },
  assistantId: {
    type: Number,
    required: true,
  },
  assistantName: {
    type: String,
    default: '',
  },
  onClose: {
    type: Function,
    default: () => {},
  },
});

const { t } = useI18n();

const showModal = ref(props.show);
const question = ref(props.questionText);
const answer = ref(props.answerText);
const isSaving = ref(false);
const errorMessage = ref('');

watch(
  () => props.show,
  val => {
    showModal.value = val;
  }
);

watch(
  () => props.questionText,
  val => {
    question.value = val;
  }
);

watch(
  () => props.answerText,
  val => {
    answer.value = val;
  }
);

const canSave = computed(() => {
  return (
    question.value.trim().length > 0 &&
    answer.value.trim().length > 0 &&
    !isSaving.value
  );
});

async function handleSave() {
  isSaving.value = true;
  errorMessage.value = '';

  try {
    await CaptainResponsesAPI.create({
      assistant_response: {
        question: question.value.trim(),
        answer: answer.value.trim(),
        assistant_id: props.assistantId,
        status: 'approved',
      },
    });
    useAlert(t('CONVERSATION.LEARN_THIS_MODAL.SUCCESS'));
    props.onClose();
  } catch (error) {
    errorMessage.value =
      error?.response?.data?.error ||
      error?.response?.data?.message ||
      t('CONVERSATION.LEARN_THIS_MODAL.ERROR');
  } finally {
    isSaving.value = false;
  }
}
</script>

<template>
  <Modal v-model:show="showModal" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('CONVERSATION.LEARN_THIS_MODAL.TITLE')"
        :header-content="$t('CONVERSATION.LEARN_THIS_MODAL.DESCRIPTION')"
      />
      <!-- Assistant badge -->
      <div v-if="assistantName" class="px-8 pb-2">
        <span
          class="inline-flex items-center px-2 py-0.5 rounded-full text-xs bg-n-alpha-1 text-n-slate-11"
        >
          {{ assistantName }}
        </span>
      </div>
      <form class="flex flex-col w-full" @submit.prevent="handleSave">
        <div class="w-full">
          <label>
            {{ $t('CONVERSATION.LEARN_THIS_MODAL.QUESTION_LABEL') }}
            <textarea v-model="question" rows="3" class="min-h-[4.5rem]" />
          </label>
        </div>
        <div class="w-full">
          <label>
            {{ $t('CONVERSATION.LEARN_THIS_MODAL.ANSWER_LABEL') }}
            <textarea
              v-model="answer"
              rows="5"
              class="min-h-[7.5rem]"
              :placeholder="
                $t('CONVERSATION.LEARN_THIS_MODAL.ANSWER_PLACEHOLDER')
              "
            />
          </label>
        </div>
        <p
          v-if="errorMessage"
          class="px-8 text-n-ruby-11 text-xs mb-2"
          role="alert"
        >
          {{ errorMessage }}
        </p>
        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <NextButton
            faded
            slate
            :label="$t('CONVERSATION.LEARN_THIS_MODAL.CANCEL')"
            @click.prevent="onClose"
          />
          <NextButton
            type="submit"
            :label="$t('CONVERSATION.LEARN_THIS_MODAL.SAVE')"
            :disabled="!canSave"
            :is-loading="isSaving"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>
