import { DateTime } from 'luxon';
import { Action, IAction } from '../../models/Action';
import { ActionOccurrence } from '../../models/ActionOccurrence';
import { Goal, IGoal } from '../../models/Goal';
import { IUser, User } from '../../models/User';
import { env } from '../../config/env';
import { logger } from '../../config/logger';
import { atLocalTime, eachDay, localDayStart, weekdayIndex } from '../../utils/date';

/**
 * Turns PLANS (Action + routine) into dated LOG rows (ActionOccurrence).
 *
 * This is the heart of the product. Because occurrences exist as real documents:
 *   - "today" is a range query, not a recurrence calculation in the UI
 *   - a day that passes without completion can be marked `missed`
 *   - the calendar, weekly targets, streaks and reminders all read one collection
 *
 * Safe to run repeatedly: the unique index {action, scheduledDate} makes writes
 * idempotent.
 */

/** Which local days in [from, to] this action should occupy. */
function plannedDays(action: IAction, goal: IGoal, from: DateTime, to: DateTime): DateTime[] {
  const recurrence = action.recurrence ?? { type: 'specific_days', days: [], timesPerWeek: 3 };
  const type = action.isRecurring ? recurrence.type : 'once';

  if (type === 'once') {
    if (!action.dueDate) return [];
    const due = DateTime.fromJSDate(action.dueDate).setZone(from.zone);
    return due >= from.startOf('day') && due <= to.endOf('day') ? [due.startOf('day')] : [];
  }

  const window = eachDay(from, to).filter((d) => {
    const goalStart = DateTime.fromJSDate(goal.startDate).setZone(from.zone).startOf('day');
    const goalEnd = DateTime.fromJSDate(goal.targetDate).setZone(from.zone).endOf('day');
    if (d < goalStart || d > goalEnd) return false;
    if (recurrence.endDate && d > DateTime.fromJSDate(recurrence.endDate)) return false;
    return true;
  });

  if (type === 'daily') return window;

  // Action-level days win; otherwise inherit the goal's routine (personalisation
  // flows down instead of being re-entered on every action).
  const days = recurrence.days?.length ? recurrence.days : goal.routine?.days ?? [];

  if (type === 'specific_days') {
    return window.filter((d) => days.includes(weekdayIndex(d)));
  }

  // weekly_count: spread N sessions across the user's preferred days each week.
  const n = recurrence.timesPerWeek || goal.routine?.timesPerWeek || 3;
  const byWeek = new Map<string, DateTime[]>();
  for (const d of window) {
    const key = d.startOf('week').toISODate() ?? '';
    if (!byWeek.has(key)) byWeek.set(key, []);
    byWeek.get(key)!.push(d);
  }
  const picked: DateTime[] = [];
  for (const week of byWeek.values()) {
    const preferred = days.length ? week.filter((d) => days.includes(weekdayIndex(d))) : week;
    const pool = preferred.length >= n ? preferred : week;
    picked.push(...pool.slice(0, n));
  }
  return picked;
}

function resolveTime(action: IAction, goal: IGoal, user: IUser): string {
  return (
    action.preferredTime || goal.routine?.startTime || user.preferences?.preferredStartTime || '09:00'
  );
}

export async function materialiseForAction(
  action: IAction,
  goal: IGoal,
  user: IUser,
  daysAhead = env.MATERIALISE_DAYS_AHEAD,
): Promise<number> {
  if (!action.isActive || goal.status !== 'active') return 0;

  const tz = user.timezone || 'Asia/Kolkata';
  const today = DateTime.now().setZone(tz).startOf('day');
  const until = today.plus({ days: daysAhead });
  const time = resolveTime(action, goal, user);

  const days = plannedDays(action, goal, today, until);
  if (!days.length) return 0;

  const ops = days.map((day) => {
    const at = atLocalTime(day, time);
    return {
      updateOne: {
        filter: { action: action._id, scheduledDate: localDayStart(day) },
        update: {
          $setOnInsert: {
            user: user._id,
            action: action._id,
            goal: goal._id,
            milestone: action.milestone,
            scheduledDate: localDayStart(day),
            scheduledAt: at.toUTC().toJSDate(),
            title: action.title,
            estimatedMinutes: action.estimatedMinutes,
            priority: action.priority,
            status: 'upcoming' as const,
          },
        },
        upsert: true,
      },
    };
  });

  const res = await ActionOccurrence.bulkWrite(ops, { ordered: false });
  await Action.updateOne(
    { _id: action._id },
    { materialisedUntil: until.toUTC().toJSDate() },
  );
  return res.upsertedCount ?? 0;
}

export async function materialiseForUser(user: IUser, daysAhead?: number): Promise<number> {
  const goals = await Goal.find({ user: user._id, status: 'active' });
  if (!goals.length) return 0;

  const goalMap = new Map(goals.map((g) => [String(g._id), g]));
  const actions = await Action.find({
    user: user._id,
    isActive: true,
    goal: { $in: goals.map((g) => g._id) },
  });

  let total = 0;
  for (const action of actions) {
    const goal = goalMap.get(String(action.goal));
    if (goal) total += await materialiseForAction(action, goal, user, daysAhead);
  }
  return total;
}

/** Nightly sweep across every user. */
export async function materialiseAll(): Promise<void> {
  const cursor = User.find({ onboardingCompleted: true }).cursor();
  let users = 0;
  let created = 0;
  for await (const user of cursor) {
    created += await materialiseForUser(user);
    users += 1;
  }
  logger.info({ users, created }, 'Materialised upcoming occurrences');
}

/**
 * Anything still `upcoming` after its day has ended in the user's own timezone
 * becomes `missed`. This is what makes the progress status honest.
 */
export async function markMissedOccurrences(): Promise<void> {
  const users = await User.find({ onboardingCompleted: true }).select('timezone');
  let missed = 0;

  for (const user of users) {
    const cutoff = DateTime.now()
      .setZone(user.timezone || 'Asia/Kolkata')
      .startOf('day')
      .toUTC()
      .toJSDate();

    const res = await ActionOccurrence.updateMany(
      { user: user._id, status: { $in: ['upcoming', 'in_progress'] }, scheduledDate: { $lt: cutoff } },
      { $set: { status: 'missed' } },
    );
    missed += res.modifiedCount;
  }
  logger.info({ missed }, 'Marked missed occurrences');
}
