export const DEFAULT_MESSAGE_CREATED_CONDITION = [
  {
    attribute_key: 'message_type',
    filter_operator: 'equal_to',
    values: '',
    query_operator: 'and',
    custom_attribute_type: '',
  },
];

export const DEFAULT_CONVERSATION_CONDITION = [
  {
    attribute_key: 'browser_language',
    filter_operator: 'equal_to',
    values: '',
    query_operator: 'and',
    custom_attribute_type: '',
  },
];

export const DEFAULT_OTHER_CONDITION = [
  {
    attribute_key: 'status',
    filter_operator: 'equal_to',
    values: '',
    query_operator: 'and',
    custom_attribute_type: '',
  },
];

export const DEFAULT_ACTIONS = [
  {
    action_name: 'assign_agent',
    action_params: [],
  },
];

export const MESSAGE_CONDITION_VALUES = [
  {
    id: 'incoming',
    name: 'Incoming',
    i18nKey: 'INCOMING',
  },
  {
    id: 'outgoing',
    name: 'Outgoing',
    i18nKey: 'OUTGOING',
  },
];

export const DAY_OF_WEEK_CONDITION_VALUES = [
  { id: 'monday', name: 'Monday', i18nKey: 'MONDAY' },
  { id: 'tuesday', name: 'Tuesday', i18nKey: 'TUESDAY' },
  { id: 'wednesday', name: 'Wednesday', i18nKey: 'WEDNESDAY' },
  { id: 'thursday', name: 'Thursday', i18nKey: 'THURSDAY' },
  { id: 'friday', name: 'Friday', i18nKey: 'FRIDAY' },
  { id: 'saturday', name: 'Saturday', i18nKey: 'SATURDAY' },
  { id: 'sunday', name: 'Sunday', i18nKey: 'SUNDAY' },
];

export const PRIORITY_CONDITION_VALUES = [
  {
    id: 'nil',
    name: 'None',
    i18nKey: 'NONE',
  },
  {
    id: 'low',
    name: 'Low',
    i18nKey: 'LOW',
  },
  {
    id: 'medium',
    name: 'Medium',
    i18nKey: 'MEDIUM',
  },
  {
    id: 'high',
    name: 'High',
    i18nKey: 'HIGH',
  },
  {
    id: 'urgent',
    name: 'Urgent',
    i18nKey: 'URGENT',
  },
];
