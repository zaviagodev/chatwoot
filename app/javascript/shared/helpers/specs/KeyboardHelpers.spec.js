import {
  isEnter,
  isEscape,
  hasPressedShift,
  hasPressedCommand,
  isActiveElementTypeable,
} from '../KeyboardHelpers';

describe('#KeyboardHelpers', () => {
  describe('#isEnter', () => {
    it('return correct values', () => {
      expect(isEnter({ key: 'Enter' })).toEqual(true);
    });
  });

  describe('#isEscape', () => {
    it('return correct values', () => {
      expect(isEscape({ key: 'Escape' })).toEqual(true);
    });
  });

  describe('#hasPressedShift', () => {
    it('return correct values', () => {
      expect(hasPressedShift({ shiftKey: true })).toEqual(true);
    });
  });

  describe('#hasPressedCommand', () => {
    it('returns true for metaKey (macOS Cmd)', () => {
      expect(hasPressedCommand({ metaKey: true, ctrlKey: false })).toEqual(
        true
      );
    });
    it('returns true for ctrlKey (Windows/Linux Ctrl)', () => {
      expect(hasPressedCommand({ metaKey: false, ctrlKey: true })).toEqual(
        true
      );
    });
    it('returns false when neither is pressed', () => {
      expect(hasPressedCommand({ metaKey: false, ctrlKey: false })).toEqual(
        false
      );
    });
  });
});

describe('isActiveElementTypeable', () => {
  it('should return true if the active element is an input element', () => {
    const event = { target: document.createElement('input') };
    const result = isActiveElementTypeable(event);
    expect(result).toBe(true);
  });

  it('should return true if the active element is a textarea element', () => {
    const event = { target: document.createElement('textarea') };
    const result = isActiveElementTypeable(event);
    expect(result).toBe(true);
  });

  it('should return true if the active element is a contentEditable element', () => {
    const element = document.createElement('div');
    element.contentEditable = 'true';
    const event = { target: element };
    const result = isActiveElementTypeable(event);
    expect(result).toBe(true);
  });

  it('should return false if the active element is not typeable', () => {
    const event = { target: document.createElement('div') };
    const result = isActiveElementTypeable(event);
    expect(result).toBe(false);
  });

  it('should return false if the active element is null', () => {
    const event = { target: null };
    const result = isActiveElementTypeable(event);
    expect(result).toBe(false);
  });
});
