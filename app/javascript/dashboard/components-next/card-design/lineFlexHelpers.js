/**
 * Helpers for LineFlexPreview component.
 * Pure functions — no Vue dependencies, safe to test in isolation.
 */

/**
 * Validates and sanitizes a hex color string to prevent CSS injection.
 * Only allows valid hex color formats (#RGB, #RRGGBB, #RRGGBBAA).
 */
export function sanitizeHex(hex, fallback = '#FFFFFF') {
  if (typeof hex !== 'string') return fallback;
  return /^#[0-9A-Fa-f]{3,8}$/.test(hex) ? hex : fallback;
}

/**
 * Computes BT.601 relative luminance (simplified, no sRGB linearization).
 * Returns a value between 0 (black) and 1 (white).
 */
export function getRelativeLuminance(hex) {
  const safe = sanitizeHex(hex, '#FFFFFF');
  const r = parseInt(safe.slice(1, 3), 16) / 255;
  const g = parseInt(safe.slice(3, 5), 16) / 255;
  const b = parseInt(safe.slice(5, 7), 16) / 255;
  return 0.299 * r + 0.587 * g + 0.114 * b;
}

/**
 * Returns true if the given hex color is dark enough to need light text on top.
 * Threshold 0.6 (not 0.5) compensates for missing sRGB gamma correction.
 */
export function isDarkColor(hex) {
  return getRelativeLuminance(hex) < 0.6;
}

export const SIZE_MAP = {
  sm: 'font-size: 12px; line-height: 16px;',
  md: 'font-size: 14px; line-height: 20px;',
  lg: 'font-size: 16px; line-height: 24px;',
  xl: 'font-size: 18px; line-height: 28px;',
};

export const WEIGHT_MAP = {
  regular: 'font-weight: 400;',
  bold: 'font-weight: 600;',
};

export const ASPECT_RATIO_MAP = {
  '20:13': '20 / 13',
  '1:1': '1 / 1',
  '4:3': '4 / 3',
};

export const CURRENCY_LOCALE_MAP = {
  THB: 'th-TH',
  USD: 'en-US',
  EUR: 'de-DE',
  JPY: 'ja-JP',
  GBP: 'en-GB',
};

export const PLACEHOLDER_CONTENT = {
  item_name: 'Sample Product',
  price: 1290,
  currency: 'THB',
  image_url: null,
};
