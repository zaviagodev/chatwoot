<script setup>
import { ref } from 'vue';
import CaptainErpProxy from 'dashboard/api/captain/erpProxy';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  field: { type: Object, required: true },
  modelValue: { type: String, default: '' },
  assistantId: { type: Number, required: true },
  error: { type: String, default: '' },
  isRequired: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);

const isUploading = ref(false);
const uploadError = ref('');
const fileName = ref('');
const fileInputRef = ref(null);

const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

const handleFileSelect = async event => {
  const file = event.target.files?.[0];
  if (!file) return;

  // Client-side size validation
  if (file.size > MAX_FILE_SIZE) {
    uploadError.value = 'File exceeds 5MB limit';
    if (fileInputRef.value) fileInputRef.value.value = '';
    return;
  }

  // Client-side type validation (only when allowed_file_types is specified)
  if (
    props.field.allowed_file_types &&
    props.field.allowed_file_types !== '*'
  ) {
    const allowed = props.field.allowed_file_types
      .split(',')
      .map(t => t.trim().toLowerCase());
    const fileExt = '.' + (file.name.split('.').pop() || '').toLowerCase();
    const matchesType = allowed.some(
      a =>
        file.type === a || fileExt === a || a === file.type.split('/')[0] + '/*'
    );
    if (!matchesType) {
      uploadError.value = `Allowed types: ${props.field.allowed_file_types}`;
      if (fileInputRef.value) fileInputRef.value.value = '';
      return;
    }
  }

  isUploading.value = true;
  uploadError.value = '';

  try {
    const { data } = await CaptainErpProxy.uploadCustomizationFile({
      assistantId: props.assistantId,
      file,
    });
    const result = data?.data || data || {};
    const fileUrl = result.file_url || result.url || '';
    fileName.value = file.name;
    emit('update:modelValue', fileUrl);
  } catch (err) {
    uploadError.value =
      err?.response?.data?.error || 'Upload failed. Please try again.';
  } finally {
    isUploading.value = false;
  }
};

const removeFile = () => {
  fileName.value = '';
  emit('update:modelValue', '');
  if (fileInputRef.value) {
    fileInputRef.value.value = '';
  }
};
</script>

<template>
  <div class="personalization-field">
    <label class="personalization-field-label">
      {{ field.label }}
      <span v-if="isRequired" class="personalization-field-required">*</span>
      <span v-if="field.addon_price" class="personalization-field-addon">
        (+{{ field.addon_price }})
      </span>
    </label>

    <!-- Upload button (no file selected) -->
    <div v-if="!modelValue && !isUploading" class="personalization-file-upload">
      <input
        ref="fileInputRef"
        type="file"
        :accept="field.allowed_file_types || '*'"
        class="personalization-file-input"
        @change="handleFileSelect"
      />
      <div class="personalization-file-dropzone">
        <Icon icon="i-lucide-paperclip" :size="14" />
        <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
        <span>Choose file...</span>
      </div>
    </div>

    <!-- Uploading state -->
    <div v-else-if="isUploading" class="personalization-file-uploading">
      <Spinner size="small" />
      <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
      <span>Uploading...</span>
    </div>

    <!-- File uploaded -->
    <div v-else-if="modelValue" class="personalization-file-uploaded">
      <span class="personalization-file-name">{{ fileName || 'File' }}</span>
      <!-- eslint-disable vue/no-bare-strings-in-template -->
      <button
        class="personalization-file-remove"
        aria-label="Remove file"
        @click="removeFile"
      >
        <Icon icon="i-lucide-x" :size="12" />
      </button>
      <!-- eslint-enable vue/no-bare-strings-in-template -->
    </div>

    <span v-if="error || uploadError" class="personalization-field-error">
      {{ error || uploadError }}
    </span>
  </div>
</template>

<style scoped>
.personalization-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.personalization-field-label {
  font-size: 12px;
  font-weight: 500;
  color: var(--s-700);
}
.personalization-field-required {
  color: var(--r-500);
  margin-left: 2px;
}
.personalization-field-addon {
  color: var(--s-500);
  font-size: 11px;
  font-weight: 400;
  margin-left: 4px;
}
.personalization-field-error {
  font-size: 11px;
  color: var(--r-500);
}
.personalization-file-upload {
  position: relative;
}
.personalization-file-input {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
  cursor: pointer;
}
.personalization-file-dropzone {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 12px;
  border: 1px dashed var(--s-200);
  border-radius: var(--border-radius-small);
  font-size: 13px;
  color: var(--s-600);
  cursor: pointer;
}
.personalization-file-dropzone:hover {
  border-color: var(--s-400);
  background: var(--s-25);
}
.personalization-file-uploading {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  font-size: 13px;
  color: var(--s-500);
}
.personalization-file-uploaded {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 6px 10px;
  background: var(--s-50);
  border-radius: var(--border-radius-small);
}
.personalization-file-name {
  font-size: 12px;
  color: var(--s-700);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.personalization-file-remove {
  background: none;
  border: none;
  cursor: pointer;
  color: var(--s-500);
  padding: 2px;
  border-radius: var(--border-radius-small);
  display: flex;
  align-items: center;
}
.personalization-file-remove:hover {
  color: var(--r-500);
  background: var(--r-50);
}
</style>
