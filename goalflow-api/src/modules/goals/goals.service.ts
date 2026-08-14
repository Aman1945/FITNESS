import { DateTime } from 'luxon';
import { Types } from 'mongoose';
import { Goal, IGoal } from '../../models/Goal';
import { Milestone } from '../../models/Milestone';
import { Action } from '../../models/Action';
import { ActionOccurrence } from '../../models/ActionOccurrence';
import { IUser } from '../../models/User';
import { ApiError } from '../../utils/ApiError';
import { evaluateGoal, recomputeGoal } from './goal.status.service';
import { materialiseForUser } from '../occurrences/materialiser.service';

export async function createGoal(user: IUser, input: Record<string, unknown>) {
  const goal = await Goal.create({ ...input, user: user._id });
  await recomputeGoal(goal);
  return goal;
}

export async function listGoals(
  userId: string,
  filters: { status?: string; category?: string; q?: string },
) {
  const query: Record<string, unknown> = { user: userId };
  if (filters.status) query.status = filters.status;
  else query.status = { $ne: 'archived' };
  if (filters.category) query.category = filters.category;
  if (filters.q) query.title = { $regex: filters.q, $options: 'i' };

  const goals = await Goal.find(query).sort({ status: 1, priority: -1, targetDate: 1 });

  // One aggregate for all goals rather than N queries in a loop.
  const ids = goals.map((g) => g._id);
  const rows = await ActionOccurrence.aggregate<{
    _id: { goal: Types.ObjectId; status: string };
    count: number;
  }>([
    { $match: { goal: { $in: ids } } },
    { $group: { _id: { goal: '$goal', status: '$status' }, count: { $sum: 1 } } },
  ]);

  const stats = new Map<string, { completed: number; total: number }>();
  for (const r of rows) {
    const key = String(r._id.goal);
    const s = stats.get(key) ?? { completed: 0, total: 0 };
    s.total += r.count;
    if (r._id.status === 'completed') s.completed += r.count;
    stats.set(key, s);
  }

  return goals.map((g) => ({
    ...g.toJSON(),
    counts: stats.get(String(g._id)) ?? { completed: 0, total: 0 },
  }));
}

export async function getGoalDetail(userId: string, goalId: string) {
  const goal = await Goal.findOne({ _id: goalId, user: userId });
  if (!goal) throw ApiError.notFound('Goal not found');

  const [milestones, actions, evaluation, recent] = await Promise.all([
    Milestone.find({ goal: goal._id }).sort({ order: 1, createdAt: 1 }),
    Action.find({ goal: goal._id, isActive: true }).sort({ createdAt: 1 }),
    evaluateGoal(goal),
    ActionOccurrence.find({ goal: goal._id, status: { $ne: 'upcoming' } })
      .sort({ scheduledDate: -1 })
      .limit(14),
  ]);

  const byMilestone = new Map<string, unknown[]>();
  const unassigned: unknown[] = [];
  for (const a of actions) {
    const key = a.milestone ? String(a.milestone) : '';
    if (!key) unassigned.push(a.toJSON());
    else {
      if (!byMilestone.has(key)) byMilestone.set(key, []);
      byMilestone.get(key)!.push(a.toJSON());
    }
  }

  return {
    goal: goal.toJSON(),
    evaluation,
    milestones: milestones.map((m) => ({
      ...m.toJSON(),
      actions: byMilestone.get(String(m._id)) ?? [],
    })),
    standaloneActions: unassigned,
    history: recent.map((o) => o.toJSON()),
  };
}

export async function updateGoal(user: IUser, goalId: string, patch: Record<string, unknown>) {
  const goal = await Goal.findOne({ _id: goalId, user: user._id });
  if (!goal) throw ApiError.notFound('Goal not found');

  Object.assign(goal, patch);
  if (goal.targetDate <= goal.startDate) {
    throw ApiError.badRequest('Target date must be after the start date');
  }
  await goal.save();

  // Routine changes must reshape the plan, not just the record.
  if (patch.routine || patch.startDate || patch.targetDate) {
    await ActionOccurrence.deleteMany({
      goal: goal._id,
      status: 'upcoming',
      scheduledDate: { $gte: DateTime.now().startOf('day').toJSDate() },
    });
    await materialiseForUser(user);
  }

  await recomputeGoal(goal);
  return Goal.findById(goal._id);
}

export async function setGoalStatus(
  user: IUser,
  goalId: string,
  status: 'active' | 'paused' | 'completed' | 'archived',
) {
  const goal = await Goal.findOne({ _id: goalId, user: user._id });
  if (!goal) throw ApiError.notFound('Goal not found');

  goal.status = status;
  if (status === 'paused') {
    goal.pausedAt = new Date();
    // Pausing must stop future noise; past history stays untouched.
    await ActionOccurrence.deleteMany({
      goal: goal._id,
      status: 'upcoming',
      scheduledDate: { $gte: DateTime.now().startOf('day').toJSDate() },
    });
  }
  if (status === 'active') {
    goal.pausedAt = undefined;
    goal.completedAt = undefined;
  }
  if (status === 'completed') {
    goal.completedAt = new Date();
    goal.progressPercent = 100;
    await ActionOccurrence.updateMany(
      { goal: goal._id, status: 'upcoming' },
      { status: 'skipped' },
    );
  }
  await goal.save();

  if (status === 'active') await materialiseForUser(user);
  await recomputeGoal(goal);
  return goal;
}

export async function deleteGoal(userId: string, goalId: string) {
  const goal = await Goal.findOne({ _id: goalId, user: userId });
  if (!goal) throw ApiError.notFound('Goal not found');

  // Archive rather than destroy: history is part of the product (JD section 6).
  goal.status = 'archived';
  await goal.save();
  await Action.updateMany({ goal: goal._id }, { isActive: false });
  await ActionOccurrence.deleteMany({ goal: goal._id, status: 'upcoming' });
  return goal;
}

export async function getGoalProgressHistory(userId: string, goalId: string, weeks = 8) {
  const goal = await Goal.findOne({ _id: goalId, user: userId });
  if (!goal) throw ApiError.notFound('Goal not found');

  const from = DateTime.now().minus({ weeks: weeks - 1 }).startOf('week');
  const rows = await ActionOccurrence.aggregate<{
    _id: { week: number; year: number; status: string };
    count: number;
  }>([
    { $match: { goal: goal._id, scheduledDate: { $gte: from.toJSDate() } } },
    {
      $group: {
        _id: {
          year: { $isoWeekYear: '$scheduledDate' },
          week: { $isoWeek: '$scheduledDate' },
          status: '$status',
        },
        count: { $sum: 1 },
      },
    },
  ]);

  const buckets: Record<string, { label: string; planned: number; completed: number; missed: number }> = {};
  for (let i = 0; i < weeks; i += 1) {
    const d = from.plus({ weeks: i });
    buckets[`${d.weekYear}-${d.weekNumber}`] = {
      label: d.toFormat('dd LLL'),
      planned: 0,
      completed: 0,
      missed: 0,
    };
  }
  for (const r of rows) {
    const key = `${r._id.year}-${r._id.week}`;
    const b = buckets[key];
    if (!b) continue;
    b.planned += r.count;
    if (r._id.status === 'completed') b.completed += r.count;
    if (r._id.status === 'missed') b.missed += r.count;
  }

  return Object.values(buckets);
}

export async function ensureGoalOwned(userId: string, goalId: string): Promise<IGoal> {
  const goal = await Goal.findOne({ _id: goalId, user: userId });
  if (!goal) throw ApiError.notFound('Goal not found');
  return goal;
}
