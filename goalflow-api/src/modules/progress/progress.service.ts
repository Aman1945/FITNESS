import { DateTime } from 'luxon';
import { ActionOccurrence } from '../../models/ActionOccurrence';
import { Goal } from '../../models/Goal';
import { IUser } from '../../models/User';
import { localDayStart, pct, weekBounds } from '../../utils/date';

/**
 * CONSISTENCY (JD section 12)
 * A day counts only if something was actually planned for it. Days with nothing
 * planned are NEUTRAL -- they neither break nor extend the streak. That is the
 * deliberate anti-gamification choice: the number stays honest, and a rest day
 * the user themselves scheduled is not punished.
 */
export async function getConsistency(user: IUser) {
  const tz = user.timezone || 'Asia/Kolkata';
  const today = DateTime.now().setZone(tz).startOf('day');
  const from = today.minus({ days: 89 });

  const rows = await ActionOccurrence.aggregate<{
    _id: string;
    planned: number;
    completed: number;
  }>([
    {
      $match: {
        user: user._id,
        scheduledDate: { $gte: localDayStart(from), $lte: localDayStart(today) },
      },
    },
    {
      $group: {
        _id: {
          $dateToString: { format: '%Y-%m-%d', date: '$scheduledDate', timezone: tz },
        },
        planned: { $sum: { $cond: [{ $ne: ['$status', 'skipped'] }, 1, 0] } },
        completed: { $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] } },
      },
    },
  ]);

  const byDay = new Map(rows.map((r) => [r._id, r]));

  let currentStreak = 0;
  for (let i = 0; i < 90; i += 1) {
    const key = today.minus({ days: i }).toISODate()!;
    const day = byDay.get(key);
    if (!day || day.planned === 0) continue; // neutral day
    if (day.completed > 0) currentStreak += 1;
    else if (i === 0) continue; // today is not over yet
    else break;
  }

  let longestStreak = 0;
  let run = 0;
  for (let i = 89; i >= 0; i -= 1) {
    const key = today.minus({ days: i }).toISODate()!;
    const day = byDay.get(key);
    if (!day || day.planned === 0) continue;
    if (day.completed > 0) {
      run += 1;
      longestStreak = Math.max(longestStreak, run);
    } else run = 0;
  }

  const { start, end } = weekBounds(today);
  const week = rows.filter((r) => {
    const d = DateTime.fromISO(r._id, { zone: tz });
    return d >= start && d <= end;
  });
  const weekPlanned = week.reduce((s, r) => s + r.planned, 0);
  const weekCompleted = week.reduce((s, r) => s + r.completed, 0);

  const month = rows.filter((r) => DateTime.fromISO(r._id, { zone: tz }) >= today.minus({ days: 29 }));
  const monthPlanned = month.reduce((s, r) => s + r.planned, 0);
  const monthCompleted = month.reduce((s, r) => s + r.completed, 0);

  // 7-day strip for the dashboard.
  const last7 = Array.from({ length: 7 }, (_, i) => {
    const d = today.minus({ days: 6 - i });
    const row = byDay.get(d.toISODate()!);
    return {
      date: d.toISODate(),
      label: d.toFormat('ccccc'),
      planned: row?.planned ?? 0,
      completed: row?.completed ?? 0,
      state: !row || row.planned === 0 ? 'rest' : row.completed > 0 ? 'done' : d.hasSame(today, 'day') ? 'today' : 'missed',
    };
  });

  return {
    currentStreak,
    longestStreak,
    week: {
      planned: weekPlanned,
      completed: weekCompleted,
      target: user.preferences?.weeklyTargetActions ?? weekPlanned,
      percent: weekPlanned === 0 ? 0 : pct(weekCompleted / weekPlanned),
    },
    month: {
      planned: monthPlanned,
      completed: monthCompleted,
      percent: monthPlanned === 0 ? 0 : pct(monthCompleted / monthPlanned),
    },
    last7,
  };
}

/** Multi-week trend for the Progress screen. */
export async function getSummary(user: IUser, range: 'week' | 'month' | 'quarter' = 'month') {
  const tz = user.timezone || 'Asia/Kolkata';
  const now = DateTime.now().setZone(tz);
  const weeks = range === 'week' ? 4 : range === 'month' ? 8 : 12;
  const from = now.minus({ weeks: weeks - 1 }).startOf('week');

  const [byWeek, byCategory, byStatus, goals] = await Promise.all([
    ActionOccurrence.aggregate([
      { $match: { user: user._id, scheduledDate: { $gte: from.toJSDate() } } },
      {
        $group: {
          _id: { y: { $isoWeekYear: '$scheduledDate' }, w: { $isoWeek: '$scheduledDate' } },
          planned: { $sum: { $cond: [{ $ne: ['$status', 'skipped'] }, 1, 0] } },
          completed: { $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] } },
          minutes: { $sum: { $ifNull: ['$actualMinutes', 0] } },
        },
      },
      { $sort: { '_id.y': 1, '_id.w': 1 } },
    ]),
    ActionOccurrence.aggregate([
      { $match: { user: user._id, status: 'completed' } },
      { $lookup: { from: 'goals', localField: 'goal', foreignField: '_id', as: 'g' } },
      { $unwind: '$g' },
      { $group: { _id: '$g.category', count: { $sum: 1 }, minutes: { $sum: { $ifNull: ['$actualMinutes', 0] } } } },
      { $sort: { count: -1 } },
    ]),
    ActionOccurrence.aggregate([
      { $match: { user: user._id, scheduledDate: { $gte: from.toJSDate() } } },
      { $group: { _id: '$status', count: { $sum: 1 } } },
    ]),
    Goal.find({ user: user._id, status: 'active' }).select(
      'title category progressPercent computedStatus statusReason targetDate color',
    ),
  ]);

  const trend = Array.from({ length: weeks }, (_, i) => {
    const d = from.plus({ weeks: i });
    const row = byWeek.find((r) => r._id.y === d.weekYear && r._id.w === d.weekNumber);
    return {
      label: d.toFormat('dd LLL'),
      weekStart: d.toISODate(),
      planned: row?.planned ?? 0,
      completed: row?.completed ?? 0,
      minutes: row?.minutes ?? 0,
      percent: row?.planned ? pct(row.completed / row.planned) : 0,
    };
  });

  const statusCounts = Object.fromEntries(byStatus.map((r) => [r._id, r.count]));

  return {
    range,
    trend,
    byCategory: byCategory.map((c) => ({ category: c._id, completed: c.count, minutes: c.minutes })),
    totals: {
      completed: statusCounts.completed ?? 0,
      missed: statusCounts.missed ?? 0,
      skipped: statusCounts.skipped ?? 0,
      upcoming: statusCounts.upcoming ?? 0,
      minutes: trend.reduce((s, t) => s + t.minutes, 0),
    },
    goals: goals.map((g) => g.toJSON()),
    consistency: await getConsistency(user),
  };
}
