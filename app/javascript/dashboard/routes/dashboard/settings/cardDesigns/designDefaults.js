export const DEFAULT_SECTION_ORDER = [
  'hero',
  'title',
  'subtitle',
  'price',
  'button',
];

export const DEFAULT_DESIGN_JSON = {
  section_order: [...DEFAULT_SECTION_ORDER],
  sections: {
    hero: { enabled: true, aspect_ratio: '20:13' },
    title: { enabled: true, size: 'lg', weight: 'bold' },
    subtitle: { enabled: false, size: 'md', color: '#999999' },
    price: { enabled: true, size: 'md', color: '#666666' },
    button: { enabled: true, label: 'View Product', style: 'primary' },
  },
  colors: {
    background: '#FFFFFF',
    accent: '#06C755',
  },
};

// Sections pinned to fixed positions (LINE Flex Message constraint)
export const PINNED_SECTIONS = { hero: 'first', button: 'last' };

export const SECTION_DEFINITIONS = [
  {
    key: 'hero',
    label: 'Hero Image',
    locked: false,
    controls: [
      {
        key: 'aspect_ratio',
        label: 'Aspect Ratio',
        type: 'select',
        options: [
          { label: '20:13', value: '20:13' },
          { label: '1:1', value: '1:1' },
          { label: '4:3', value: '4:3' },
        ],
      },
    ],
  },
  {
    key: 'title',
    label: 'Title',
    locked: true,
    controls: [
      {
        key: 'size',
        label: 'Size',
        type: 'select',
        options: [
          { label: 'Small', value: 'sm' },
          { label: 'Medium', value: 'md' },
          { label: 'Large', value: 'lg' },
          { label: 'Extra Large', value: 'xl' },
        ],
      },
      {
        key: 'weight',
        label: 'Weight',
        type: 'select',
        options: [
          { label: 'Regular', value: 'regular' },
          { label: 'Bold', value: 'bold' },
        ],
      },
    ],
  },
  {
    key: 'subtitle',
    label: 'Subtitle',
    locked: false,
    controls: [
      {
        key: 'size',
        label: 'Size',
        type: 'select',
        options: [
          { label: 'Small', value: 'sm' },
          { label: 'Medium', value: 'md' },
        ],
      },
      { key: 'color', label: 'Color', type: 'color' },
    ],
  },
  {
    key: 'price',
    label: 'Price',
    locked: false,
    controls: [
      {
        key: 'size',
        label: 'Size',
        type: 'select',
        options: [
          { label: 'Small', value: 'sm' },
          { label: 'Medium', value: 'md' },
          { label: 'Large', value: 'lg' },
        ],
      },
      { key: 'color', label: 'Color', type: 'color' },
    ],
  },
  {
    key: 'button',
    label: 'Button',
    locked: false,
    controls: [
      { key: 'label', label: 'Label', type: 'text' },
      {
        key: 'style',
        label: 'Style',
        type: 'select',
        options: [
          { label: 'Primary', value: 'primary' },
          { label: 'Link', value: 'link' },
        ],
      },
    ],
  },
];
