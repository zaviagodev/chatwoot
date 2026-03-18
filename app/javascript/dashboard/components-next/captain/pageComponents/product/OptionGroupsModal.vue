<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  optionGroups: { type: Array, default: () => [] },
  existingVariants: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue', 'apply']);
const { t } = useI18n();

const SUGGESTION_NAMES = [
  'Color',
  'Size',
  'Material',
  'Style',
  'Weight',
  'Flavor',
  'Roast',
];
const MAX_GROUPS = 3;

// Local working copy of option groups
const groups = ref([]);
const tagInputValues = ref({});
const confirmRemoval = ref(null); // { groupIndex, valueIndex, affectedVariants }

// Initialize when modal opens
watch(
  () => props.modelValue,
  open => {
    if (!open) return;
    if (props.optionGroups?.length) {
      groups.value = JSON.parse(JSON.stringify(props.optionGroups));
    } else {
      groups.value = [{ name: '', values: [] }];
    }
    tagInputValues.value = {};
    confirmRemoval.value = null;
  }
);

// Live variant count
const variantCount = computed(() => {
  const filled = groups.value.filter(g => g.name && g.values.length > 0);
  if (filled.length === 0) return 0;
  return filled.reduce((acc, g) => acc * g.values.length, 1);
});

const canApply = computed(() => {
  return groups.value.some(g => g.name?.trim() && g.values.length > 0);
});

const canAddGroup = computed(() => {
  return groups.value.length < MAX_GROUPS;
});

// Available suggestions (exclude already-used names)
const availableSuggestions = computed(() => {
  const used = new Set(groups.value.map(g => g.name?.toLowerCase()));
  return SUGGESTION_NAMES.filter(n => !used.has(n.toLowerCase()));
});

// --- Tag input handlers ---
const addTagValue = (groupIndex, val) => {
  const group = groups.value[groupIndex];
  const normalized = val.trim();
  if (!normalized) return;
  // Avoid duplicates (case-insensitive)
  if (group.values.some(v => v.toLowerCase() === normalized.toLowerCase()))
    return;
  group.values.push(normalized);
  tagInputValues.value[groupIndex] = '';
};

const removeTagValue = (groupIndex, valueIndex) => {
  const group = groups.value[groupIndex];
  const removedValue = group.values[valueIndex];

  // Check if existing variants use this value
  const affected = props.existingVariants.filter(v =>
    v.attributes?.some(
      a => a.attribute === group.name && a.value === removedValue
    )
  );

  if (affected.length > 0) {
    confirmRemoval.value = {
      groupIndex,
      valueIndex,
      affectedVariants: affected,
      valueName: removedValue,
    };
  } else {
    group.values.splice(valueIndex, 1);
  }
};

const handleTagKeydown = (e, groupIndex) => {
  const val = tagInputValues.value[groupIndex]?.trim();
  if ((e.key === 'Enter' || e.key === ',') && val) {
    e.preventDefault();
    addTagValue(groupIndex, val);
  } else if (e.key === 'Backspace' && !tagInputValues.value[groupIndex]) {
    const group = groups.value[groupIndex];
    if (group.values.length > 0) {
      removeTagValue(groupIndex, group.values.length - 1);
    }
  }
};

const confirmRemoveValue = () => {
  if (!confirmRemoval.value) return;
  const { groupIndex, valueIndex } = confirmRemoval.value;
  groups.value[groupIndex].values.splice(valueIndex, 1);
  confirmRemoval.value = null;
};

const cancelRemoveValue = () => {
  confirmRemoval.value = null;
};

const addGroup = () => {
  if (groups.value.length >= MAX_GROUPS) return;
  groups.value.push({ name: '', values: [] });
};

const removeGroup = index => {
  groups.value.splice(index, 1);
  if (groups.value.length === 0) {
    groups.value.push({ name: '', values: [] });
  }
};

// --- Apply ---
const handleApply = () => {
  // Filter to only groups with name and values
  const validGroups = groups.value
    .filter(g => g.name?.trim() && g.values.length > 0)
    .map(g => ({ name: g.name.trim(), values: [...g.values] }));

  emit('apply', validGroups);
  emit('update:modelValue', false);
};

const handleCancel = () => {
  emit('update:modelValue', false);
};
</script>

<template>
  <Dialog
    :model-value="modelValue"
    size="large"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <template #header>
      <h2 class="text-lg font-semibold text-n-slate-12">
        {{ t('CAPTAIN_PRODUCTS.OPTION_GROUPS.MODAL_TITLE') }}
      </h2>
    </template>

    <template #body>
      <div class="space-y-5 py-2">
        <!-- Option group slots -->
        <div
          v-for="(group, gIdx) in groups"
          :key="gIdx"
          class="space-y-2 p-4 rounded-lg border border-n-slate-3 bg-n-alpha-1"
        >
          <div class="flex items-center justify-between">
            <label class="text-sm font-medium text-n-slate-11">
              {{
                t('CAPTAIN_PRODUCTS.OPTION_GROUPS.OPTION_LABEL', {
                  n: gIdx + 1,
                })
              }}
            </label>
            <button
              v-if="groups.length > 1"
              class="text-xs text-n-slate-9 hover:text-r-500"
              @click="removeGroup(gIdx)"
            >
              {{ t('CAPTAIN_PRODUCTS.OPTION_GROUPS.REMOVE_OPTION') }}
            </button>
          </div>

          <!-- Name input with datalist suggestions -->
          <div>
            <label class="text-xs text-n-slate-10 block mb-1">
              {{ t('CAPTAIN_PRODUCTS.OPTION_GROUPS.NAME_LABEL') }}
            </label>
            <input
              v-model="group.name"
              :list="`option-suggestions-${gIdx}`"
              :placeholder="
                t('CAPTAIN_PRODUCTS.OPTION_GROUPS.NAME_PLACEHOLDER')
              "
              class="!mb-0 w-full"
            />
            <datalist :id="`option-suggestions-${gIdx}`">
              <option
                v-for="suggestion in availableSuggestions"
                :key="suggestion"
                :value="suggestion"
              />
            </datalist>
          </div>

          <!-- Values tag input -->
          <div>
            <label class="text-xs text-n-slate-10 block mb-1">
              {{ t('CAPTAIN_PRODUCTS.OPTION_GROUPS.VALUES_LABEL') }}
            </label>
            <div
              class="flex flex-wrap gap-1.5 items-center min-h-[40px] px-2 py-1.5 rounded-lg border border-n-slate-4 bg-n-surface-1 focus-within:ring-1 focus-within:ring-b-500 focus-within:border-b-500"
            >
              <span
                v-for="(val, vIdx) in group.values"
                :key="vIdx"
                class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-sm bg-n-alpha-3 text-n-slate-12"
              >
                {{ val }}
                <button
                  class="text-n-slate-9 hover:text-r-500 ml-0.5"
                  :aria-label="
                    t('CAPTAIN_PRODUCTS.OPTION_GROUPS.REMOVE_VALUE_ARIA', {
                      value: val,
                    })
                  "
                  @click="removeTagValue(gIdx, vIdx)"
                >
                  <span class="i-lucide-x w-3 h-3" />
                </button>
              </span>
              <input
                v-model="tagInputValues[gIdx]"
                :placeholder="
                  group.values.length === 0
                    ? t('CAPTAIN_PRODUCTS.OPTION_GROUPS.VALUES_PLACEHOLDER')
                    : ''
                "
                class="flex-1 min-w-[80px] border-none outline-none bg-transparent text-sm text-n-slate-12 placeholder:text-n-slate-8 !p-0 !m-0 !ring-0"
                :disabled="!group.name"
                @keydown="handleTagKeydown($event, gIdx)"
              />
            </div>
            <p class="text-xs text-n-slate-9 mt-1">
              {{ t('CAPTAIN_PRODUCTS.OPTION_GROUPS.VALUES_HINT') }}
            </p>
          </div>
        </div>

        <!-- Add another option button -->
        <button
          v-if="canAddGroup"
          class="text-sm text-b-600 hover:text-b-700 font-medium"
          @click="addGroup"
        >
          <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
          + {{ t('CAPTAIN_PRODUCTS.OPTION_GROUPS.ADD_OPTION') }}
        </button>
        <p v-else class="text-xs text-n-slate-9">
          {{ t('CAPTAIN_PRODUCTS.OPTION_GROUPS.MAX_REACHED') }}
        </p>

        <!-- Variant count -->
        <div class="border-t border-n-slate-3 pt-3">
          <p class="text-sm text-n-slate-11">
            {{
              t('CAPTAIN_PRODUCTS.OPTION_GROUPS.VARIANT_COUNT', {
                count: variantCount,
              })
            }}
          </p>
          <p v-if="variantCount > 50" class="text-xs text-n-amber-11 mt-1">
            {{ t('CAPTAIN_PRODUCTS.OPTION_GROUPS.MANY_VARIANTS_WARNING') }}
          </p>
        </div>

        <!-- Removal confirmation -->
        <div
          v-if="confirmRemoval"
          class="p-3 rounded-lg border border-n-amber-6 bg-n-amber-1"
        >
          <p class="text-sm text-n-slate-12">
            {{
              t('CAPTAIN_PRODUCTS.OPTION_GROUPS.REMOVE_CONFIRM_MESSAGE', {
                count: confirmRemoval.affectedVariants.length,
                value: confirmRemoval.valueName,
              })
            }}
          </p>
          <p class="text-xs text-n-slate-10 mt-1">
            {{
              confirmRemoval.affectedVariants
                .map(v => v.item_name)
                .slice(0, 5)
                .join(', ')
            }}
          </p>
          <div class="flex gap-2 mt-2">
            <Button
              size="sm"
              color="alert"
              :label="t('CAPTAIN_PRODUCTS.OPTION_GROUPS.REMOVE_CONFIRM')"
              @click="confirmRemoveValue"
            />
            <Button
              size="sm"
              variant="faded"
              color="slate"
              :label="t('CAPTAIN_PRODUCTS.OPTION_GROUPS.REMOVE_CANCEL')"
              @click="cancelRemoveValue"
            />
          </div>
        </div>
      </div>
    </template>

    <template #footer>
      <div class="flex justify-end gap-2">
        <Button
          variant="faded"
          color="slate"
          :label="t('CAPTAIN_PRODUCTS.OPTION_GROUPS.CANCEL')"
          @click="handleCancel"
        />
        <Button
          :label="t('CAPTAIN_PRODUCTS.OPTION_GROUPS.APPLY')"
          :disabled="!canApply"
          @click="handleApply"
        />
      </div>
    </template>
  </Dialog>
</template>
