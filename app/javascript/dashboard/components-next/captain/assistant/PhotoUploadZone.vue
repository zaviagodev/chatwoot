<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: {
    type: Object,
    default: () => ({
      newFiles: [],
      existingPhotos: [],
      removedSignedIds: [],
    }),
  },
});

const emit = defineEmits(['update:modelValue']);

const MAX_PHOTOS = 4;

const { t } = useI18n();
const fileInputRef = ref(null);

const visiblePhotos = computed(() =>
  props.modelValue.existingPhotos.filter(
    p => !props.modelValue.removedSignedIds.includes(p.signed_id)
  )
);

const newFilePreviews = computed(() =>
  props.modelValue.newFiles.map(file => ({
    file,
    url: URL.createObjectURL(file),
  }))
);

const totalCount = computed(
  () => visiblePhotos.value.length + props.modelValue.newFiles.length
);

const canAdd = computed(() => totalCount.value < MAX_PHOTOS);

const handleFileSelect = event => {
  const files = Array.from(event.target.files || []);
  const remaining = MAX_PHOTOS - totalCount.value;
  const accepted = files.slice(0, remaining);
  if (accepted.length) {
    emit('update:modelValue', {
      ...props.modelValue,
      newFiles: [...props.modelValue.newFiles, ...accepted],
    });
  }
  if (fileInputRef.value) fileInputRef.value.value = '';
};

const removeExisting = signedId => {
  emit('update:modelValue', {
    ...props.modelValue,
    removedSignedIds: [...props.modelValue.removedSignedIds, signedId],
  });
};

const removeNew = index => {
  const updated = [...props.modelValue.newFiles];
  updated.splice(index, 1);
  emit('update:modelValue', {
    ...props.modelValue,
    newFiles: updated,
  });
};

const openFilePicker = () => {
  fileInputRef.value?.click();
};
</script>

<template>
  <div>
    <div class="grid grid-cols-4 gap-2">
      <!-- Existing photos -->
      <div
        v-for="photo in visiblePhotos"
        :key="photo.signed_id"
        class="relative aspect-square rounded-lg overflow-hidden border border-n-slate-5 group"
      >
        <img
          :src="photo.url"
          :alt="photo.filename || 'Review photo'"
          class="w-full h-full object-cover"
        />
        <button
          type="button"
          class="absolute top-1 right-1 p-0.5 rounded-full bg-black/50 text-white opacity-0 group-hover:opacity-100 transition-opacity"
          @click="removeExisting(photo.signed_id)"
        >
          <span class="i-lucide-x text-xs" />
        </button>
      </div>

      <!-- New file previews -->
      <div
        v-for="(preview, index) in newFilePreviews"
        :key="`new-${index}`"
        class="relative aspect-square rounded-lg overflow-hidden border border-n-slate-5 group"
      >
        <img
          :src="preview.url"
          :alt="preview.file.name"
          class="w-full h-full object-cover"
        />
        <button
          type="button"
          class="absolute top-1 right-1 p-0.5 rounded-full bg-black/50 text-white opacity-0 group-hover:opacity-100 transition-opacity"
          @click="removeNew(index)"
        >
          <span class="i-lucide-x text-xs" />
        </button>
      </div>

      <!-- Add button -->
      <button
        v-if="canAdd"
        type="button"
        class="aspect-square rounded-lg border-2 border-dashed border-n-slate-5 hover:border-n-blue-7 flex flex-col items-center justify-center gap-1 text-n-slate-8 hover:text-n-blue-11 transition-colors"
        @click="openFilePicker"
      >
        <span class="i-lucide-plus text-lg" />
        <span class="text-xs">
          {{ t('CAPTAIN_REVIEWS.DRAWER.ADD_PHOTO') }}
        </span>
      </button>
    </div>

    <p class="text-xs text-n-slate-8 mt-2">{{ totalCount }}/{{ MAX_PHOTOS }}</p>

    <input
      ref="fileInputRef"
      type="file"
      accept="image/*"
      multiple
      class="hidden"
      @change="handleFileSelect"
    />
  </div>
</template>
