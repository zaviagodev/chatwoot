/**
 * Client-side rule evaluation engine for Item Customization Templates.
 *
 * Plain JS port of enterprise-commerce rule-engine.ts.
 * Semantics:
 *   - Case-insensitive matching on all string comparisons
 *   - Each rule evaluated independently (condition → action)
 *   - Priority-based conflict resolution (higher wins, same → lower idx)
 *   - Cascading visibility: rules whose when_field is hidden are suppressed.
 *     Uses iterative evaluation (max 5 passes) until visibility stabilizes.
 */

function findLabelCaseInsensitive(labels, target) {
  const targetLower = (target || '').trim().toLowerCase();
  return (
    labels.find(label => label.trim().toLowerCase() === targetLower) || null
  );
}

function getValueCaseInsensitive(values, key) {
  const keyLower = (key || '').trim().toLowerCase();
  const entry = Object.entries(values).find(
    ([k]) => k.trim().toLowerCase() === keyLower
  );
  return entry ? entry[1] : null;
}

function actionCategory(action) {
  if (action === 'Show Field' || action === 'Hide Field') return 'visibility';
  if (action === 'Set Value' || action === 'Force Value') return 'value';
  if (action === 'Set Required' || action === 'Clear Required')
    return 'required';
  return action;
}

export function checkCondition(operator, fieldValue, expectedValue) {
  const fv = fieldValue == null ? '' : String(fieldValue).trim();
  const ev = expectedValue == null ? '' : String(expectedValue).trim();
  const fvLower = fv.toLowerCase();
  const evLower = ev.toLowerCase();

  switch (operator) {
    case 'equals':
      return fvLower === evLower;
    case 'not_equals':
      return fvLower !== evLower;
    case 'is_set':
      return fv.length > 0;
    case 'is_empty':
      return fv.length === 0;
    case 'contains':
      return fvLower.includes(evLower);
    default:
      return false;
  }
}

function resolveConflicts(actions) {
  if (actions.length === 0) return [];

  const best = {};
  actions.forEach(a => {
    const key = `${a.target_field.trim().toLowerCase()}|${actionCategory(a.action)}`;
    const existing = best[key];

    if (!existing) {
      best[key] = a;
    } else if (a.priority > existing.priority) {
      best[key] = a;
    } else if (a.priority === existing.priority && a.idx < existing.idx) {
      best[key] = a;
    }
  });

  return Object.values(best);
}

/**
 * Evaluate all rules against current field values.
 *
 * @param {Array} fields - Array of {label, required, ...} field definitions
 * @param {Array} rules - Array of {when_field, operator, has_value, then_action, target_field, target_value, priority, idx}
 * @param {Object} currentValues - {fieldLabel: value} map of current form values
 * @returns {{visible: Object, forced: Object, required: Object}}
 */
export function evaluateRules(fields, rules, currentValues) {
  const fieldLabels = fields.map(f => f.label || '');

  // Fields that are targets of "Show Field" rules default to hidden
  const showTargets = new Set();
  if (rules && rules.length > 0) {
    rules.forEach(rule => {
      if (
        (rule.then_action || 'Show Field') === 'Show Field' &&
        rule.target_field
      ) {
        const matched = findLabelCaseInsensitive(
          fieldLabels,
          rule.target_field
        );
        if (matched) showTargets.add(matched);
      }
    });
  }

  const result = {
    visible: Object.fromEntries(fieldLabels.map(l => [l, !showTargets.has(l)])),
    forced: Object.fromEntries(fieldLabels.map(l => [l, null])),
    required: Object.fromEntries(
      fields.map(f => [f.label || '', !!f.required])
    ),
  };

  if (!rules || rules.length === 0) return result;

  let prevVisibleKey = '';
  const requiredDefaults = Object.fromEntries(
    fields.map(f => [f.label || '', !!f.required])
  );

  for (let pass = 0; pass < 5; pass += 1) {
    const filterVisible = { ...result.visible };

    // Reset to defaults before each pass
    fieldLabels.forEach(l => {
      result.visible[l] = !showTargets.has(l);
      result.forced[l] = null;
      result.required[l] = requiredDefaults[l] ?? false;
    });

    // Evaluate each rule, skipping rules whose when_field is hidden
    const triggeredActions = [];
    rules.forEach((rule, i) => {
      const whenLabel = findLabelCaseInsensitive(
        fieldLabels,
        rule.when_field || ''
      );
      if (whenLabel && filterVisible[whenLabel] === false) return;

      const fieldVal = getValueCaseInsensitive(
        currentValues,
        rule.when_field || ''
      );
      if (
        checkCondition(
          rule.operator || 'equals',
          fieldVal,
          rule.has_value || ''
        )
      ) {
        triggeredActions.push({
          action: rule.then_action || 'Show Field',
          target_field: rule.target_field || '',
          target_value: rule.target_value || '',
          priority: rule.priority ?? 10,
          idx: rule.idx ?? i,
        });
      }
    });

    // Resolve conflicts and apply
    const resolved = resolveConflicts(triggeredActions);
    resolved.forEach(a => {
      const matched = findLabelCaseInsensitive(fieldLabels, a.target_field);
      if (matched) {
        switch (a.action) {
          case 'Show Field':
            result.visible[matched] = true;
            break;
          case 'Hide Field':
            result.visible[matched] = false;
            break;
          case 'Set Value':
          case 'Force Value':
            result.forced[matched] = a.target_value;
            break;
          case 'Set Required':
            result.required[matched] = true;
            break;
          case 'Clear Required':
            result.required[matched] = false;
            break;
          default:
            break;
        }
      }
    });

    const visibleKey = JSON.stringify(result.visible);
    if (visibleKey === prevVisibleKey) break;
    prevVisibleKey = visibleKey;
  }

  return result;
}
