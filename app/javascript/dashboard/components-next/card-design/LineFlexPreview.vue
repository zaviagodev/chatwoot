<script setup>
import { computed, ref, onMounted, onUnmounted, watch } from 'vue';
import {
  sanitizeHex,
  isDarkColor,
  SIZE_MAP,
  WEIGHT_MAP,
  ASPECT_RATIO_MAP,
  CURRENCY_LOCALE_MAP,
  PLACEHOLDER_CONTENT,
} from './lineFlexHelpers.js';

const props = defineProps({
  designJson: {
    type: Object,
    required: true,
  },
  contentData: {
    type: Object,
    default: null,
  },
  scale: {
    type: Number,
    default: 1,
  },
  showFrame: {
    type: Boolean,
    default: false,
  },
});

// --- Computed: Content ---

const content = computed(() => props.contentData || PLACEHOLDER_CONTENT);

// --- Computed: Sections ---

const sections = computed(() => props.designJson?.sections || {});

const DEFAULT_ORDER = ['hero', 'title', 'subtitle', 'price', 'button'];
const bodyOrder = computed(() => {
  const order = props.designJson?.section_order || DEFAULT_ORDER;
  return order.filter(k => k !== 'hero' && k !== 'button');
});

const heroConfig = computed(() => sections.value.hero || { enabled: false });
const titleConfig = computed(
  () => sections.value.title || { enabled: true, size: 'lg', weight: 'bold' }
);
const subtitleConfig = computed(
  () =>
    sections.value.subtitle || { enabled: false, size: 'md', color: '#999999' }
);
const priceConfig = computed(
  () => sections.value.price || { enabled: false, size: 'md', color: '#666666' }
);
const buttonConfig = computed(
  () =>
    sections.value.button || {
      enabled: false,
      label: 'View Product',
      style: 'primary',
    }
);

// --- Computed: Colors ---

const bgColor = computed(() =>
  sanitizeHex(props.designJson?.colors?.background, '#FFFFFF')
);
const accentColor = computed(() =>
  sanitizeHex(props.designJson?.colors?.accent, '#06C755')
);

const autoTextColor = computed(() =>
  isDarkColor(bgColor.value) ? '#FFFFFF' : '#111111'
);
const autoAccentTextColor = computed(() =>
  isDarkColor(accentColor.value) ? '#FFFFFF' : '#111111'
);

// --- Computed: Hero ---

const showHero = computed(() => heroConfig.value.enabled);
const heroAspectRatio = computed(
  () => ASPECT_RATIO_MAP[heroConfig.value.aspect_ratio] || '20 / 13'
);

const imageUrl = computed(() => content.value.image_url || null);
const imageError = ref(false);
const showPlaceholderImage = computed(
  () => !imageUrl.value || imageError.value
);

watch(
  () => content.value.image_url,
  () => {
    imageError.value = false;
  }
);

function onImageError() {
  imageError.value = true;
}

// --- Computed: Body ---

const titleStyle = computed(() => {
  const size = SIZE_MAP[titleConfig.value.size] || SIZE_MAP.lg;
  const weight = WEIGHT_MAP[titleConfig.value.weight] || WEIGHT_MAP.bold;
  return `${size} ${weight} color: ${autoTextColor.value};`;
});

const subtitleStyle = computed(() => {
  const size = SIZE_MAP[subtitleConfig.value.size] || SIZE_MAP.md;
  const color = sanitizeHex(subtitleConfig.value.color, '#999999');
  return `${size} color: ${color};`;
});

const priceStyle = computed(() => {
  const size = SIZE_MAP[priceConfig.value.size] || SIZE_MAP.md;
  const color = sanitizeHex(priceConfig.value.color, '#666666');
  return `${size} color: ${color};`;
});

const formattedPrice = computed(() => {
  const { price, currency } = content.value;
  if (price == null) return '';
  if (!price && price !== 0) return '';
  const curr = currency || 'THB';
  const locale = CURRENCY_LOCALE_MAP[curr] || 'en-US';
  try {
    return new Intl.NumberFormat(locale, {
      style: 'currency',
      currency: curr,
      minimumFractionDigits: 0,
      maximumFractionDigits: 2,
    }).format(price);
  } catch {
    return `${curr} ${price}`;
  }
});

const showPrice = computed(() => {
  return (
    priceConfig.value.enabled &&
    content.value.price != null &&
    content.value.price !== ''
  );
});

// --- Computed: Button ---

const buttonLabel = computed(() => buttonConfig.value.label || 'View Product');
const isPrimaryButton = computed(() => buttonConfig.value.style !== 'link');

const buttonStyle = computed(() => {
  if (isPrimaryButton.value) {
    return [
      `background-color: ${accentColor.value}`,
      `color: ${autoAccentTextColor.value}`,
      'border: none',
      'padding: 10px 16px',
      'border-radius: 6px',
      'text-align: center',
      'font-size: 14px',
      'font-weight: 600',
      'cursor: default',
    ].join('; ');
  }
  return [
    'background: transparent',
    `color: ${accentColor.value}`,
    'border: none',
    'padding: 10px 16px',
    'text-align: center',
    'font-size: 14px',
    'font-weight: 600',
    'cursor: default',
  ].join('; ');
});

// --- Scale / ResizeObserver ---

const cardRef = ref(null);
const cardHeight = ref(400);
let resizeObserver = null;

onMounted(() => {
  if (cardRef.value) {
    resizeObserver = new ResizeObserver(([entry]) => {
      cardHeight.value = entry.contentRect.height;
    });
    resizeObserver.observe(cardRef.value);
  }
});

onUnmounted(() => {
  if (resizeObserver) {
    resizeObserver.disconnect();
    resizeObserver = null;
  }
});

const containerStyle = computed(() => {
  if (props.scale === 1) return 'width: 280px;';
  const w = Math.round(280 * props.scale);
  const h = Math.round(cardHeight.value * props.scale);
  return `width: ${w}px; height: ${h}px; overflow: hidden;`;
});

const cardTransformStyle = computed(() => {
  if (props.scale === 1) return '';
  return `transform: scale(${props.scale}); transform-origin: top left;`;
});
</script>

<template>
  <div class="line-flex-preview-root">
    <!-- Optional LINE chat frame wrapper -->
    <div v-if="showFrame" class="line-flex-frame">
      <!-- Scale container + card rendered inside frame -->
      <div :style="containerStyle">
        <div
          ref="cardRef"
          class="line-flex-card"
          :style="`background-color: ${bgColor}; ${cardTransformStyle}`"
        >
          <!-- Hero -->
          <Transition name="lfp-fade">
            <div
              v-if="showHero"
              class="line-flex-hero"
              :style="`aspect-ratio: ${heroAspectRatio};`"
            >
              <img
                v-if="!showPlaceholderImage"
                :src="imageUrl"
                :alt="content.item_name || 'Product'"
                class="line-flex-hero-img"
                @error="onImageError"
              />
              <div v-else class="line-flex-hero-placeholder">
                <svg
                  width="48"
                  height="48"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path
                    d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"
                  />
                  <polyline points="3.27 6.96 12 12.01 20.73 6.96" />
                  <!-- eslint-disable-next-line vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
                  <line x1="12" y1="22.08" x2="12" y2="12" />
                </svg>
              </div>
            </div>
          </Transition>

          <!-- Body -->
          <div class="line-flex-body">
            <template v-for="sKey in bodyOrder" :key="sKey">
              <div
                v-if="sKey === 'title'"
                class="line-flex-title"
                :style="titleStyle"
              >
                {{ content.item_name || 'Product' }}
              </div>
              <Transition v-else-if="sKey === 'subtitle'" name="lfp-fade">
                <div
                  v-if="subtitleConfig.enabled"
                  class="line-flex-subtitle"
                  :style="subtitleStyle"
                >
                  {{ content.subtitle || 'Product description' }}
                </div>
              </Transition>
              <Transition v-else-if="sKey === 'price'" name="lfp-fade">
                <div
                  v-if="showPrice"
                  class="line-flex-price"
                  :style="priceStyle"
                >
                  {{ formattedPrice }}
                </div>
              </Transition>
            </template>
          </div>

          <!-- Footer -->
          <Transition name="lfp-fade">
            <div v-if="buttonConfig.enabled" class="line-flex-footer">
              <div
                class="line-flex-button"
                :style="buttonStyle"
                role="presentation"
              >
                {{ buttonLabel }}
              </div>
            </div>
          </Transition>
        </div>
      </div>

      <!-- eslint-disable-next-line vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
      <p class="line-flex-caption">This is how your card appears on LINE</p>
    </div>

    <!-- Without frame: just the scale container + card -->
    <div v-else :style="containerStyle">
      <div
        ref="cardRef"
        class="line-flex-card"
        :style="`background-color: ${bgColor}; ${cardTransformStyle}`"
      >
        <!-- Hero -->
        <Transition name="lfp-fade">
          <div
            v-if="showHero"
            class="line-flex-hero"
            :style="`aspect-ratio: ${heroAspectRatio};`"
          >
            <img
              v-if="!showPlaceholderImage"
              :src="imageUrl"
              :alt="content.item_name || 'Product'"
              class="line-flex-hero-img"
              @error="onImageError"
            />
            <div v-else class="line-flex-hero-placeholder">
              <svg
                width="48"
                height="48"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path
                  d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"
                />
                <polyline points="3.27 6.96 12 12.01 20.73 6.96" />
                <!-- eslint-disable-next-line vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
                <line x1="12" y1="22.08" x2="12" y2="12" />
              </svg>
            </div>
          </div>
        </Transition>

        <!-- Body -->
        <div class="line-flex-body">
          <template v-for="sKey in bodyOrder" :key="sKey">
            <div
              v-if="sKey === 'title'"
              class="line-flex-title"
              :style="titleStyle"
            >
              {{ content.item_name || 'Product' }}
            </div>
            <Transition v-else-if="sKey === 'subtitle'" name="lfp-fade">
              <div
                v-if="subtitleConfig.enabled"
                class="line-flex-subtitle"
                :style="subtitleStyle"
              >
                {{ content.subtitle || 'Product description' }}
              </div>
            </Transition>
            <Transition v-else-if="sKey === 'price'" name="lfp-fade">
              <div v-if="showPrice" class="line-flex-price" :style="priceStyle">
                {{ formattedPrice }}
              </div>
            </Transition>
          </template>
        </div>

        <!-- Footer -->
        <Transition name="lfp-fade">
          <div v-if="buttonConfig.enabled" class="line-flex-footer">
            <div
              class="line-flex-button"
              :style="buttonStyle"
              role="presentation"
            >
              {{ buttonLabel }}
            </div>
          </div>
        </Transition>
      </div>
    </div>
  </div>
</template>

<style scoped>
.line-flex-card {
  width: 280px;
  border-radius: 12px;
  overflow: hidden;
  box-shadow:
    0 1px 3px rgba(0, 0, 0, 0.12),
    0 1px 2px rgba(0, 0, 0, 0.08);
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
    'Helvetica Neue', Arial, sans-serif;
  transition: background-color 150ms ease;
}

.line-flex-frame {
  background-color: #7bc67e;
  border-radius: 8px;
  padding: 16px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.line-flex-caption {
  margin-top: 8px;
  text-align: center;
  font-size: 12px;
  font-style: italic;
  color: rgba(255, 255, 255, 0.8);
}

.line-flex-hero {
  width: 100%;
  overflow: hidden;
  background-color: #e5e7eb;
}

.line-flex-hero-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.line-flex-hero-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #9ca3af;
  background-color: #f3f4f6;
}

.line-flex-body {
  padding: 12px 16px;
}

.line-flex-title {
  word-wrap: break-word;
  overflow-wrap: break-word;
  transition: color 150ms ease;
}

.line-flex-subtitle {
  margin-top: 4px;
  word-wrap: break-word;
  overflow-wrap: break-word;
  transition:
    color 150ms ease,
    opacity 150ms ease;
}

.line-flex-price {
  margin-top: 8px;
  transition:
    color 150ms ease,
    opacity 150ms ease;
}

.line-flex-footer {
  padding: 8px 16px 12px;
  transition: opacity 150ms ease;
}

.line-flex-button {
  width: 100%;
  display: block;
  box-sizing: border-box;
}

/* Fade transition for section toggle */
.lfp-fade-enter-active,
.lfp-fade-leave-active {
  transition: opacity 150ms ease;
}

.lfp-fade-enter-from,
.lfp-fade-leave-to {
  opacity: 0;
}
</style>
