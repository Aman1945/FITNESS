import { ZodIssue } from 'zod';

/**
 * Turns Zod's developer-facing issues into sentences a user can act on.
 *
 * Zod's defaults leak implementation detail — "String must contain at least
 * 2 character(s)" tells the user neither what is wrong nor which field. Doing
 * this centrally means every endpoint gets readable errors without each schema
 * having to spell out a message for every rule.
 *
 * An explicit `message` in a schema always wins, so specific wording
 * (e.g. the password rules) is preserved.
 */

/** Field path -> the label a user would recognise. */
const LABELS: Record<string, string> = {
  // auth
  name: 'Your name',
  email: 'Email address',
  password: 'Password',
  newPassword: 'New password',
  currentPassword: 'Current password',
  code: 'Verification code',
  token: 'Reset code',
  idToken: 'Google sign-in token',

  // goal
  title: 'Title',
  description: 'Description',
  why: 'Reason',
  category: 'Category',
  customCategory: 'Category name',
  priority: 'Priority',
  startDate: 'Start date',
  targetDate: 'Target date',
  color: 'Colour',
  status: 'Status',

  // routine / recurrence
  'routine.type': 'Routine type',
  'routine.days': 'Preferred days',
  'routine.timesPerWeek': 'Times per week',
  'routine.timeOfDay': 'Time of day',
  'routine.startTime': 'Start time',
  'routine.durationMinutes': 'Session length',
  'recurrence.type': 'Repeat pattern',
  'recurrence.days': 'Repeat days',
  'recurrence.timesPerWeek': 'Times per week',
  'recurrence.endDate': 'Repeat end date',

  // action
  goal: 'Goal',
  milestone: 'Milestone',
  estimatedMinutes: 'Duration',
  difficulty: 'Difficulty',
  dueDate: 'Due date',
  preferredTime: 'Preferred time',
  targetCount: 'Target',
  unit: 'Unit',

  // preferences
  preferredDays: 'Preferred days',
  preferredTimeOfDay: 'Preferred time of day',
  preferredStartTime: 'Preferred start time',
  defaultSessionMinutes: 'Default session length',
  weeklyTargetActions: 'Weekly target',
  progressStyle: 'Progress style',
  constraints: 'Constraints',
  mainObjective: 'Main objective',
  timezone: 'Timezone',

  // notifications
  pushEnabled: 'Push notifications',
  emailEnabled: 'Email notifications',
  minutesBefore: 'Reminder lead time',
  weekday: 'Day of the week',
  time: 'Time',
  start: 'Start time',
  end: 'End time',

  // occurrences / reflections
  date: 'Date',
  actualMinutes: 'Time spent',
  note: 'Note',
  wentWell: 'What went well',
  wasDifficult: 'What was difficult',
  improveNext: 'What to improve',
  weekStart: 'Week',
  goals: 'Goals',
};

/** Strips the leading body/query/params segment Zod reports. */
export function fieldPath(issue: ZodIssue): string {
  const path = issue.path.map(String);
  if (['body', 'query', 'params'].includes(path[0])) path.shift();
  return path.join('.');
}

export function labelFor(path: string): string {
  if (LABELS[path]) return LABELS[path];

  // Try the last segment: "goals.0.title" -> "title"
  const last = path.split('.').filter((p) => !/^\d+$/.test(p)).pop() ?? path;
  if (LABELS[last]) return LABELS[last];

  // Fall back to a title-cased version of the key: "someField" -> "Some field"
  return last
    .replace(/([A-Z])/g, ' $1')
    .replace(/^./, (c) => c.toUpperCase())
    .trim();
}

/** True when the schema author wrote their own message for this rule. */
function hasCustomMessage(issue: ZodIssue): boolean {
  const defaults = [
    'Required',
    'Invalid',
    'Invalid input',
    'Invalid date',
    'Invalid email',
    'Invalid enum value',
    'Expected',
    'String must contain',
    'Number must be',
    'Array must contain',
    'Invalid literal value',
    'Unrecognized key',
  ];
  return !defaults.some((d) => issue.message.startsWith(d));
}

export function humanizeIssue(issue: ZodIssue): { field: string; label: string; message: string } {
  const field = fieldPath(issue);
  const label = labelFor(field);

  // Respect hand-written messages, but still name the field.
  if (hasCustomMessage(issue)) {
    return { field, label, message: issue.message };
  }

  return { field, label, message: `${label} ${describe(issue, label)}` };
}

function describe(issue: ZodIssue, label: string): string {
  switch (issue.code) {
    case 'invalid_type':
      if (issue.received === 'undefined' || issue.received === 'null') {
        return 'is required.';
      }
      return `must be a ${friendlyType(issue.expected)}.`;

    case 'invalid_string':
      if (issue.validation === 'email') return 'does not look like a valid email address.';
      if (issue.validation === 'url') return 'must be a valid link.';
      if (issue.validation === 'regex') return 'is not in the expected format.';
      return 'is not valid.';

    case 'too_small': {
      const min = Number(issue.minimum);
      if (issue.type === 'string') {
        return min === 1
          ? 'cannot be empty.'
          : `needs at least ${min} characters.`;
      }
      if (issue.type === 'array') {
        return min === 1 ? 'needs at least one selection.' : `needs at least ${min} items.`;
      }
      if (issue.type === 'date') return 'is too early.';
      return `must be ${min} or more.`;
    }

    case 'too_big': {
      const max = Number(issue.maximum);
      if (issue.type === 'string') return `is too long — keep it under ${max} characters.`;
      if (issue.type === 'array') return `can have at most ${max} items.`;
      if (issue.type === 'date') return 'is too far in the future.';
      return `must be ${max} or less.`;
    }

    case 'invalid_enum_value':
      return `must be one of: ${issue.options.join(', ')}.`;

    case 'invalid_date':
      return 'is not a valid date.';

    case 'unrecognized_keys':
      return `contains unexpected fields: ${issue.keys.join(', ')}.`;

    default:
      return `is not valid.${label ? '' : ''}`;
  }
}

function friendlyType(expected: string): string {
  switch (expected) {
    case 'string':
      return 'piece of text';
    case 'number':
      return 'number';
    case 'boolean':
      return 'yes or no value';
    case 'array':
      return 'list';
    case 'date':
      return 'date';
    default:
      return expected;
  }
}

/**
 * Builds the summary line shown when the client has nowhere to put a
 * field-level error. One clear sentence beats "Validation failed".
 */
export function summarise(details: { message: string }[]): string {
  if (details.length === 0) return 'Please check the details and try again.';
  if (details.length === 1) return details[0].message;
  return `${details[0].message} (and ${details.length - 1} other ${
    details.length === 2 ? 'problem' : 'problems'
  })`;
}
