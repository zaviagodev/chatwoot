import {
  sanitizeHex,
  getRelativeLuminance,
  isDarkColor,
} from '../lineFlexHelpers.js';

describe('lineFlexHelpers', () => {
  describe('sanitizeHex', () => {
    it('passes through valid 6-digit hex', () => {
      expect(sanitizeHex('#06C755')).toBe('#06C755');
    });

    it('passes through valid 3-digit hex', () => {
      expect(sanitizeHex('#FFF')).toBe('#FFF');
    });

    it('passes through valid 8-digit hex (with alpha)', () => {
      expect(sanitizeHex('#06C755FF')).toBe('#06C755FF');
    });

    it('rejects CSS injection attempts', () => {
      expect(sanitizeHex('#FFF; background-image: url(evil)')).toBe('#FFFFFF');
    });

    it('rejects empty string', () => {
      expect(sanitizeHex('')).toBe('#FFFFFF');
    });

    it('rejects hex without hash', () => {
      expect(sanitizeHex('06C755')).toBe('#FFFFFF');
    });

    it('returns fallback for null', () => {
      expect(sanitizeHex(null)).toBe('#FFFFFF');
    });

    it('returns fallback for undefined', () => {
      expect(sanitizeHex(undefined)).toBe('#FFFFFF');
    });

    it('returns fallback for number', () => {
      expect(sanitizeHex(123)).toBe('#FFFFFF');
    });

    it('uses custom fallback', () => {
      expect(sanitizeHex(null, '#000000')).toBe('#000000');
    });
  });

  describe('getRelativeLuminance', () => {
    it('returns 0 for black', () => {
      expect(getRelativeLuminance('#000000')).toBe(0);
    });

    it('returns ~1 for white', () => {
      expect(getRelativeLuminance('#FFFFFF')).toBeCloseTo(1, 5);
    });

    it('returns ~0.299 for pure red', () => {
      const lum = getRelativeLuminance('#FF0000');
      expect(lum).toBeCloseTo(0.299, 2);
    });

    it('returns ~0.587 for pure green', () => {
      const lum = getRelativeLuminance('#00FF00');
      expect(lum).toBeCloseTo(0.587, 2);
    });

    it('returns ~0.114 for pure blue', () => {
      const lum = getRelativeLuminance('#0000FF');
      expect(lum).toBeCloseTo(0.114, 2);
    });

    it('handles invalid hex by using white fallback', () => {
      expect(getRelativeLuminance('invalid')).toBeCloseTo(1, 5);
    });
  });

  describe('isDarkColor', () => {
    it('returns true for black', () => {
      expect(isDarkColor('#000000')).toBe(true);
    });

    it('returns false for white', () => {
      expect(isDarkColor('#FFFFFF')).toBe(false);
    });

    it('returns true for dark gray (#333333)', () => {
      expect(isDarkColor('#333333')).toBe(true);
    });

    it('returns false for light gray (#CCCCCC)', () => {
      expect(isDarkColor('#CCCCCC')).toBe(false);
    });

    it('returns true for LINE green (#06C755) — threshold 0.6 catches it', () => {
      // LINE green has luminance ~0.49, which is < 0.6 threshold
      expect(isDarkColor('#06C755')).toBe(true);
    });

    it('returns true for red (#E8453C) — Promotion design accent', () => {
      expect(isDarkColor('#E8453C')).toBe(true);
    });

    it('returns false for light gray bg (#F5F5F5) — Announcement design', () => {
      expect(isDarkColor('#F5F5F5')).toBe(false);
    });
  });
});
