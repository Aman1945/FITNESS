import { DateTime } from 'luxon';
import { ActionOccurrence } from '../../models/ActionOccurrence';
import { WeeklyReflection } from '../../models/WeeklyReflection';
import { IUser } from '../../models/User';
import { pct, weekBounds } from '../../utils/date';

export interface WeekStats {
  planned: number;
  completed: number;
  missed: number;
  skipped: number;
  completionRate: number;
  goalsWorkedOn: number;
  strongestGoalTitle?: string;
  weakestGoalTitle?: string;
  minutesInvested: number;
}

export async function computeWeekStats(
  user: IUser,
  reference?: DateTime,
): Promise<{ start: DateTime; end: DateTime; stats: WeekStats; perGoal: unknown[] }> {
  const tz = user.timezone || 'Asia/Kolkata';
  const { start, end } = weekBounds(reference ?? DateTime.now().setZone(tz));

  const rows = await ActionOccurrence.aggregate([
    {
      $match: {
        user: user._id,
        scheduledDate: { $gte: start.toUTC().toJSDate(), $lte: end.toUTC().toJSDate() },
      },
    },
    { $lookup: { from: 'goals', localField: 'goal', foreignField: '_id', as: 'g' } },
    { $unwind: '$g' },
    {
      $group: {
        _id: '$goal',
        title: { $first: '$g.title' },
        category: { $first: '$g.category' },
        planned: { $sum: { $cond: [{ $ne: ['$status', 'skipped'] }, 1, 0] } },
        completed: { $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] } },
        missed: { $sum: { $cond: [{ $eq: ['$status', 'missed'] }, 1, 0] } },
        skipped: { $sum: { $cond: [{ $eq: ['$status', 'skipped'] }, 1, 0] } },
        minutes: { $sum: { $ifNull: ['$actualMinutes', 0] } },
      },
    },
  ]);

  const perGoal = rows
    .map((r) => ({
      goalId: String(r._id),
      title: r.title,
      category: r.category,
      planned: r.planned,
      completed: r.completed,
      missed: r.missed,
      minutes: r.minutes,
      percent: r.planned ? pct(r.completed / r.planned) : 0,
    }))
    .sort((a, b) => b.percent - a.percent);

  const planned = perGoal.reduce((s, g) => s + g.planned, 0);
  const completed = perGoal.reduce((s, g) => s + g.completed, 0);
  const missed = perGoal.reduce((s, g) => s + g.missed, 0);
  const skipped = rows.reduce((s, r) => s + r.skipped, 0);

  // Strongest/weakest only make sense where something was actually planned.
  const rated = perGoal.filter((g) => g.planned > 0);

  const stats: WeekStats = {
    planned,
    completed,
    missed,
    skipped,
    completionRate: planned ? pct(completed / planned) : 0,
    goalsWorkedOn: perGoal.filter((g) => g.completed > 0).length,
    strongestGoalTitle: rated[0]?.title,
    weakestGoalTitle: rated.length > 1 ? rated[rated.length - 1]?.title : undefined,
    minutesInvested: perGoal.reduce((s, g) => s + g.minutes, 0),
  };

  return { start, end, stats, perGoal };
}

export async function getCurrentReflection(user: IUser) {
  const { start, end, stats, perGoal } = await computeWeekStats(user);

  const existing = await WeeklyReflection.findOne({
    user: user._id,
    weekStart: start.toUTC().toJSDate(),
  });

  const upcoming = await ActionOccurrence.find({
    user: user._id,
    status: 'upcoming',
    scheduledDate: { $gt: end.toUTC().toJSDate() },
  })
    .populate('goal', 'title color')
    .sort({ scheduledAt: 1 })
    .limit(5);

  return {
    weekStart: start.toISODate(),
    weekEnd: end.toISODate(),
    label: `${start.toFormat('dd LLL')} - ${end.toFormat('dd LLL')}`,
    stats,
    perGoal,
    upcomingPriorities: upcoming.map((o) => o.toJSON()),
    reflection: existing?.toJSON() ?? null,
  };
}

export async function saveReflection(
  user: IUser,
  input: { wentWell?: string; wasDifficult?: string; improveNext?: string; weekStart?: string },
) {
  const tz = user.timezone || 'Asia/Kolkata';
  const ref = input.weekStart ? DateTime.fromISO(input.weekStart, { zone: tz }) : undefined;
  const { start, end, stats } = await computeWeekStats(user, ref);

  return WeeklyReflection.findOneAndUpdate(
    { user: user._id, weekStart: start.toUTC().toJSDate() },
    {
      user: user._id,
      weekStart: start.toUTC().toJSDate(),
      weekEnd: end.toUTC().toJSDate(),
      stats,
      wentWell: input.wentWell,
      wasDifficult: input.wasDifficult,
      improveNext: input.improveNext,
      submittedAt: new Date(),
    },
    { upsert: true, new: true, setDefaultsOnInsert: true },
  );
}

export async function listReflections(userId: string, limit = 12) {
  return WeeklyReflection.find({ user: userId }).sort({ weekStart: -1 }).limit(limit);
}
