<script setup>
import { reactive, computed, onMounted, defineOptions } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStoreGetters, useStore } from 'dashboard/composables/store';

import LineFlexPreview from 'dashboard/components-next/card-design/LineFlexPreview.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import EditorSectionToggle from './EditorSectionToggle.vue';
import EditorColorPicker from './EditorColorPicker.vue';
import {
  DEFAULT_DESIGN_JSON,
  DEFAULT_SECTION_ORDER,
  SECTION_DEFINITIONS,
  PINNED_SECTIONS,
} from './designDefaults';

defineOptions({ name: 'CardDesignsEditor' });

const route = useRoute();
const router = useRouter();
const store = useStore();
const storeGetters = useStoreGetters();
const { t } = useI18n();

const designId = computed(() => route.params.designId);
const isEditing = computed(() => !!designId.value);

const form = reactive({
  name: '',
  sectionOrder: [...DEFAULT_SECTION_ORDER],
  sections: JSON.parse(JSON.stringify(DEFAULT_DESIGN_JSON.sections)),
  colors: { ...DEFAULT_DESIGN_JSON.colors },
});

const sectionDefMap = Object.fromEntries(
  SECTION_DEFINITIONS.map(s => [s.key, s])
);

const orderedSections = computed(() =>
  form.sectionOrder.map(key => sectionDefMap[key]).filter(Boolean)
);

const isSaving = computed(() => {
  const flags = storeGetters.getCardDesignUIFlags.value;
  return flags.creatingItem || flags.updatingItem;
});

const designJsonForPreview = computed(() => ({
  section_order: form.sectionOrder,
  sections: form.sections,
  colors: form.colors,
}));

const editLabel = computed(() => {
  const name = form.name || t('CARD_DESIGNS.UNTITLED');
  return t('CARD_DESIGNS.EDIT_DESIGN', { name });
});

onMounted(async () => {
  if (isEditing.value) {
    await store.dispatch('getCardDesigns');
    const designs = storeGetters.getCardDesigns.value;
    const design = designs.find(d => d.id === Number(designId.value));
    if (design) {
      form.name = design.name;
      const dj = design.design_json;
      if (dj?.sections) {
        Object.keys(dj.sections).forEach(key => {
          if (form.sections[key]) {
            Object.assign(form.sections[key], dj.sections[key]);
          }
        });
      }
      if (dj?.section_order?.length) {
        form.sectionOrder = [...dj.section_order];
      }
      if (dj?.colors) {
        Object.assign(form.colors, dj.colors);
      }
    }
  }
});

const updateSectionField = (sectionKey, fieldKey, value) => {
  if (form.sections[sectionKey]) {
    form.sections[sectionKey][fieldKey] = value;
  }
};

const toggleSection = (sectionKey, enabled) => {
  if (form.sections[sectionKey]) {
    form.sections[sectionKey].enabled = enabled;
  }
};

const canMove = (sectionKey, direction) => {
  if (PINNED_SECTIONS[sectionKey]) return false;
  const idx = form.sectionOrder.indexOf(sectionKey);
  const targetIdx = idx + direction;
  if (targetIdx < 0 || targetIdx >= form.sectionOrder.length) return false;
  const targetKey = form.sectionOrder[targetIdx];
  return !PINNED_SECTIONS[targetKey];
};

const moveSection = (sectionKey, direction) => {
  if (!canMove(sectionKey, direction)) return;
  const idx = form.sectionOrder.indexOf(sectionKey);
  const targetIdx = idx + direction;
  const arr = [...form.sectionOrder];
  [arr[idx], arr[targetIdx]] = [arr[targetIdx], arr[idx]];
  form.sectionOrder = arr;
};

const handleSave = async () => {
  if (!form.name.trim()) {
    useAlert(t('CARD_DESIGNS.ENTER_NAME'));
    return;
  }

  const payload = {
    card_design: {
      name: form.name.trim(),
      design_json: {
        section_order: [...form.sectionOrder],
        sections: JSON.parse(JSON.stringify(form.sections)),
        colors: { ...form.colors },
      },
    },
  };

  try {
    if (isEditing.value) {
      await store.dispatch('updateCardDesign', {
        id: Number(designId.value),
        ...payload,
      });
    } else {
      await store.dispatch('createCardDesign', payload);
    }
    useAlert(t('CARD_DESIGNS.SAVED'));
    router.push({ name: 'card_designs_list' });
  } catch (error) {
    useAlert(error?.message || t('CARD_DESIGNS.SAVE_FAILED'));
  }
};

const handleCancel = () => {
  router.push({ name: 'card_designs_list' });
};
</script>

<template>
  <div class="flex-1 overflow-auto">
    <!-- Breadcrumb -->
    <div class="flex items-center gap-2 mb-6 text-sm">
      <button
        class="text-n-blue-9 hover:underline cursor-pointer"
        @click="handleCancel"
      >
        {{ t('CARD_DESIGNS.BREADCRUMB_ROOT') }}
      </button>
      <!-- eslint-disable-next-line vue/no-bare-strings-in-template -->
      <span class="text-n-slate-9">&sol;</span>
      <span class="text-n-slate-12">
        {{ isEditing ? editLabel : t('CARD_DESIGNS.NEW_DESIGN') }}
      </span>
    </div>

    <!-- Two-column layout -->
    <div class="flex gap-8">
      <!-- Left: Editor form -->
      <div class="flex-1 min-w-0 max-w-2xl space-y-5">
        <!-- Design name card -->
        <div class="bg-n-solid-1 rounded-lg border border-n-weak p-5">
          <label
            class="block text-xs font-semibold uppercase tracking-wider text-n-slate-9 mb-2"
          >
            {{ t('CARD_DESIGNS.DESIGN_NAME_LABEL') }}
          </label>
          <input
            v-model="form.name"
            type="text"
            :placeholder="t('CARD_DESIGNS.DESIGN_NAME_PLACEHOLDER')"
            class="w-full px-3 py-2.5 rounded-lg border border-n-weak bg-n-background text-n-slate-12 text-sm focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand transition-shadow"
          />
        </div>

        <!-- Sections card -->
        <div class="bg-n-solid-1 rounded-lg border border-n-weak">
          <div class="px-5 pt-5 pb-3">
            <div
              class="text-xs font-semibold uppercase tracking-wider text-n-slate-9"
            >
              {{ t('CARD_DESIGNS.SECTIONS_HEADER') }}
            </div>
          </div>

          <div class="border-t border-n-weak divide-y divide-n-weak">
            <EditorSectionToggle
              v-for="section in orderedSections"
              :key="section.key"
              :label="section.label"
              :enabled="form.sections[section.key]?.enabled ?? false"
              :locked="section.locked"
              :can-move-up="canMove(section.key, -1)"
              :can-move-down="canMove(section.key, 1)"
              @update:enabled="val => toggleSection(section.key, val)"
              @move-up="moveSection(section.key, -1)"
              @move-down="moveSection(section.key, 1)"
            >
              <div
                v-for="control in section.controls"
                :key="control.key"
                class="flex items-center gap-4 py-1"
              >
                <label
                  class="text-sm font-medium text-n-slate-12 w-28 shrink-0"
                >
                  {{ control.label }}
                </label>

                <!-- Select control -->
                <select
                  v-if="control.type === 'select'"
                  :value="form.sections[section.key]?.[control.key]"
                  class="!mb-0 flex-1 max-w-[240px]"
                  @change="
                    e =>
                      updateSectionField(
                        section.key,
                        control.key,
                        e.target.value
                      )
                  "
                >
                  <option
                    v-for="opt in control.options"
                    :key="opt.value"
                    :value="opt.value"
                  >
                    {{ opt.label }}
                  </option>
                </select>

                <!-- Text control -->
                <input
                  v-else-if="control.type === 'text'"
                  :value="form.sections[section.key]?.[control.key]"
                  type="text"
                  class="!mb-0 flex-1 max-w-[240px]"
                  @input="
                    e =>
                      updateSectionField(
                        section.key,
                        control.key,
                        e.target.value
                      )
                  "
                />

                <!-- Color control -->
                <EditorColorPicker
                  v-else-if="control.type === 'color'"
                  label=""
                  :model-value="
                    form.sections[section.key]?.[control.key] || '#000000'
                  "
                  @update:model-value="
                    val => updateSectionField(section.key, control.key, val)
                  "
                />
              </div>
            </EditorSectionToggle>
          </div>
        </div>

        <!-- Colors card -->
        <div class="bg-n-solid-1 rounded-lg border border-n-weak p-5">
          <div
            class="text-xs font-semibold uppercase tracking-wider text-n-slate-9 mb-4"
          >
            {{ t('CARD_DESIGNS.COLORS_HEADER') }}
          </div>
          <div class="space-y-3">
            <EditorColorPicker
              label="Background"
              :model-value="form.colors.background"
              @update:model-value="val => (form.colors.background = val)"
            />
            <EditorColorPicker
              label="Accent (button)"
              :model-value="form.colors.accent"
              @update:model-value="val => (form.colors.accent = val)"
            />
          </div>
        </div>

        <!-- Actions -->
        <div class="flex items-center gap-3 pb-6">
          <Button
            :label="t('CARD_DESIGNS.SAVE_DESIGN')"
            :is-loading="isSaving"
            @click="handleSave"
          />
          <Button
            :label="t('CARD_DESIGNS.CANCEL')"
            slate
            faded
            @click="handleCancel"
          />
        </div>
      </div>

      <!-- Right: Live preview -->
      <div class="w-[340px] shrink-0">
        <div class="sticky top-4">
          <LineFlexPreview :design-json="designJsonForPreview" show-frame />
          <p class="text-xs italic text-n-slate-9 text-center mt-3">
            {{ t('CARD_DESIGNS.PREVIEW_SUBTITLE') }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
