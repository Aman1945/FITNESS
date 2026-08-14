import { DateTime } from 'luxon';
import { ActionOccurrence } from '../../models/ActionOccurrence';
import { Goal, IGoal } from '../../models/Goal';
import { Milestone } from '../../models/Milestone';
import { ProgressStatus } from '../../models/enums';
import { clamp01, pct } from '../../utils/date';
import { logger } from '../../config/logger';

/**
 * PROGRESS STATUS ALGORITHM  (documented per JD section 11)
 * ---------------------------------------------------------
 * Deliberately not a percentage-only system. Four independent signals:
 *
 *   timeRatio  = share of the goal's calendar window already elapsed
 *   workRatio  = completed occurrences / all planned occurrences to the target date
 *   adherence  = last 14 days: completed / (completed + missed)   [skipped excluded --
 *                a consciously skipped session is a decision, not a failure]
 *   delta      = workRatio - timeRatio   (pace relative to the clock)
 *
 * Decision table, first match wins:
 *   workRatio >= 1 or status completed .................. completed
 *   goal younger than 7 days ............................ on_track   (grace period)
 *   delta >= +0.10 ...................................... ahead
 *   delta >= -0.05 AND adherence >= 0.60 ................ on_track
 *   delta >= -0.20 OR  adherence >= 0.40 ................ needs_attention
 *   otherwise ........................................... behind
 *
 * Every status is returned with a plain-language reason, because a coloured chip
 * with no explanation is the "corporate dashboard" feel this product avoids.
 */

const GRACE_DAYS = 7;
const ADHERENCE_WINDOW_DAYS = 14;

export interface GoalEvaluation {
  progressPercent: number;
  status: ProgressStatus;
  reason: string;
  metrics: {
    totalPlanned: number;
    completed: number;
    missed: number;
    skipped: number;
    remaining: number;
    timeRatio: number;
    workRatio: number;
    adherence: number;
    delta: number;
    daysRemaining: number;
  };
}

export async function evaluateGoal(goal: IGoal): Promise<GoalEvaluation> {
  const now = DateTime.now();
  const start = DateTime.fromJSDate(goal.startDate);
  const target = DateTime.fromJSDate(goal.targetDate);

  const [counts, adherenceCounts] = await Promise.all([
    ActionOccurrence.aggregate<{ _id: string; count: number; minutes: number }>([
      { $match: { goal: goal._id } },
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 },
          minutes: { $sum: { $ifNull: ['$actualMinutes', 0] } },
        },
      },
    ]),
    ActionOccurrence.aggregate<{ _id: string; count: number }>([
      {
        $match: {
          goal: goal._id,
          scheduledDate: { $gte: now.minus({ days: ADHERENCE_WINDOW_DAYS }).toJSDate() },
        },
      },
      { $group: { _id: '$status', count: { $sum: 1 } } },
    ]),
  ]);

  const by = (rows: { _id: string; count: number }[], k: string) =>
    rows.find((r) => r._id === k)?.count ?? 0;

  const completed = by(counts, 'completed');
  const missed = by(counts, 'missed');
  const skipped = by(counts, 'skipped');
  const upcoming = by(counts, 'upcoming') + by(counts, 'in_progress');
  const materialised = completed + missed + skipped + upcoming;

  // Occurrences only exist a week ahead, so the denominator projects the
  // remaining calendar at the goal's own weekly cadence.
  const perWeek = weeklyCadence(goal);
  const weeksLeft = Math.max(0, target.diff(now, 'weeks').weeks);
  const projectedRemaining = Math.round(weeksLeft * perWeek);
  const totalPlanned = Math.max(1, materialised - upcoming + Math.max(upcoming, projectedRemaining));

  const totalWindow = Math.max(1, target.diff(start, 'days').days);
  const elapsed = now.diff(start, 'days').days;
  const timeRatio = clamp01(elapsed / totalWindow);
  const workRatio = clamp01(completed / totalPlanned);

  const aCompleted = by(adherenceCounts, 'completed');
  const aMissed = by(adherenceCounts, 'missed');
  const adherence = aCompleted + aMissed === 0 ? 1 : aCompleted / (aCompleted + aMissed);

  const delta = workRatio - timeRatio;
  const ageDays = Math.max(0, elapsed);
  const daysRemaining = Math.max(0, Math.ceil(target.diff(now, 'days').days));

  const { status, reason } = decide({
    goal,
    workRatio,
    delta,
    adherence,
    ageDays,
    completed,
    missed,
    daysRemaining,
  });

  return {
    progressPercent: pct(workRatio),
    status,
    reason,
    metrics: {
      totalPlanned,
      completed,
      missed,
      skipped,
      remaining: Math.max(0, totalPlanned - completed),
      timeRatio: Number(timeRatio.toFixed(3)),
      workRatio: Number(workRatio.toFixed(3)),
      adherence: Number(adherence.toFixed(3)),
      delta: Number(delta.toFixed(3)),
      daysRemaining,
    },
  };
}

function weeklyCadence(goal: IGoal): number {
  const r = goal.routine;
  if (!r) return 3;
  if (r.type === 'daily') return 7;
  if (r.type === 'specific_days') return Math.max(1, r.days?.length ?? 3);
  if (r.type === 'weekly_count') return Math.max(1, r.timesPerWeek ?? 3);
  return 1;
}

function decide(input: {
  goal: IGoal;
  workRatio: number;
  delta: number;
  adherence: number;
  ageDays: number;
  completed: number;
  missed: number;
  daysRemaining: number;
}): { status: ProgressStatus; reason: string } {
  const { goal, workRatio, delta, adherence, ageDays, completed, missed, daysRemaining } = input;

  if (goal.status === 'completed' || workRatio >= 1) {
    return { status: 'completed', reason: `All planned actions done. ${completed} completed in total.` };
  }
  if (goal.status === 'paused') {
    return { status: 'needs_attention', reason: 'This goal is paused. Resume it when you\'re ready.' };
  }
  if (ageDays < GRACE_DAYS) {
    return {
      status: 'on_track',
      reason: completed > 0
        ? `Good start - ${completed} action${completed === 1 ? '' : 's'} done in your first week.`
        : 'Just getting started. Your first action is the one that counts.',
    };
  }
  if (delta >= 0.1) {
    return { status: 'ahead', reason: `You're ahead of schedule with ${daysRemaining} days still to go.` };
  }
  if (delta >= -0.05 && adherence >= 0.6) {
    return { status: 'on_track', reason: `Steady - you've kept ${Math.round(adherence * 100)}% of your recent sessions.` };
  }
  if (delta >= -0.2 || adherence >= 0.4) {
    return {
      status: 'needs_attention',
      reason: missed > 0
        ? `${missed} missed session${missed === 1 ? '' : 's'} is starting to show. A short session today would help.`
        : 'Slightly behind the pace you set. Try one extra session this week.',
    };
  }
  return {
    status: 'behind',
    reason: `Only ${completed} of your planned actions are done with ${daysRemaining} days left. Consider easing the routine rather than dropping the goal.`,
  };
}

/** Persist the cached derived fields on the goal + its milestones. */
export async function recomputeGoal(goal: IGoal): Promise<GoalEvaluation> {
  const evaluation = await evaluateGoal(goal);

  await Goal.updateOne(
    { _id: goal._id },
    {
      progressPercent: evaluation.progressPercent,
      computedStatus: evaluation.status,
      statusReason: evaluation.reason,
      lastEvaluatedAt: new Date(),
    },
  );

  await recomputeMilestones(goal);
  return evaluation;
}

export async function recomputeMilestones(goal: IGoal): Promise<void> {
  const milestones = await Milestone.find({ goal: goal._id });
  for (const m of milestones) {
    const rows = await ActionOccurrence.aggregate<{ _id: string; count: number }>([
      { $match: { milestone: m._id } },
      { $group: { _id: '$status', count: { $sum: 1 } } },
    ]);
    const total = rows.reduce((s, r) => s + r.count, 0);
    const done = rows.find((r) => r._id === 'completed')?.count ?? 0;
    const progress = total === 0 ? 0 : pct(done / total);

    const status =
      progress >= 100 ? 'completed' : progress > 0 ? 'in_progress' : 'pending';

    if (m.progressPercent !== progress || m.status !== status) {
      m.progressPercent = progress;
      m.status = status;
      if (status === 'completed' && !m.completedAt) m.completedAt = new Date();
      await m.save();
    }
  }
}

/** Nightly recompute for every active goal. */
export async function recomputeAllGoals(): Promise<void> {
  const cursor = Goal.find({ status: { $in: ['active', 'paused'] } }).cursor();
  let n = 0;
  for await (const goal of cursor) {
    await recomputeGoal(goal);
    n += 1;
  }
  logger.info({ goals: n }, 'Recomputed goal statuses');
}
