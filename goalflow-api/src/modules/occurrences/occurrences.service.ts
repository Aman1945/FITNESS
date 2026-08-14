import { DateTime } from 'luxon';
import { ActionOccurrence, IActionOccurrence } from '../../models/ActionOccurrence';
import { Goal } from '../../models/Goal';
import { Milestone } from '../../models/Milestone';
import { IUser } from '../../models/User';
import { ApiError } from '../../utils/ApiError';
import { localDayStart } from '../../utils/date';
import { recomputeGoal } from '../goals/goal.status.service';
import { dispatch } from '../notifications/notification.service';
import { milestoneTemplate } from '../../emails/templates';

async function owned(userId: string, id: string): Promise<IActionOccurrence> {
  const o = await ActionOccurrence.findOne({ _id: id, user: userId });
  if (!o) throw ApiError.notFound('Action not found for that day');
  return o;
}

export async function listRange(
  userId: string,
  tz: string,
  from?: string,
  to?: string,
  status?: string,
) {
  const start = from
    ? DateTime.fromISO(from, { zone: tz }).startOf('day')
    : DateTime.now().setZone(tz).startOf('week');
  const end = to
    ? DateTime.fromISO(to, { zone: tz }).endOf('day')
    : start.plus({ days: 30 });

  const query: Record<string, unknown> = {
    user: userId,
    scheduledDate: { $gte: localDayStart(start), $lte: localDayStart(end) },
  };
  if (status) query.status = status;

  const rows = await ActionOccurrence.find(query)
    .populate('goal', 'title category color')
    .sort({ scheduledAt: 1 });

  return rows.map((r) => r.toJSON());
}

export async function getToday(user: IUser) {
  const tz = user.timezone || 'Asia/Kolkata';
  const today = DateTime.now().setZone(tz).startOf('day');

  const [todayRows, overdue] = await Promise.all([
    ActionOccurrence.find({ user: user._id, scheduledDate: localDayStart(today) })
      .populate('goal', 'title category color')
      .sort({ scheduledAt: 1 }),
    // Yesterday's misses stay visible for one day -- catching up should be easy.
    ActionOccurrence.find({
      user: user._id,
      status: 'missed',
      scheduledDate: {
        $gte: localDayStart(today.minus({ days: 1 })),
        $lt: localDayStart(today),
      },
    })
      .populate('goal', 'title category color')
      .limit(5),
  ]);

  return {
    date: today.toISODate(),
    actions: todayRows.map((r) => r.toJSON()),
    carriedOver: overdue.map((r) => r.toJSON()),
    summary: {
      planned: todayRows.length,
      completed: todayRows.filter((r) => r.status === 'completed').length,
      minutesPlanned: todayRows
        .filter((r) => r.status !== 'skipped')
        .reduce((s, r) => s + (r.estimatedMinutes ?? 0), 0),
    },
  };
}

export async function setStatus(
  user: IUser,
  id: string,
  status: 'in_progress' | 'completed' | 'skipped' | 'upcoming',
  extra?: { actualMinutes?: number; note?: string },
) {
  const occ = await owned(user.id, id);

  occ.status = status;
  if (status === 'in_progress') occ.startedAt = new Date();
  if (status === 'completed') {
    occ.completedAt = new Date();
    occ.actualMinutes = extra?.actualMinutes ?? occ.estimatedMinutes;
  }
  if (status === 'upcoming') {
    occ.completedAt = undefined;
    occ.actualMinutes = undefined;
  }
  if (extra?.note !== undefined) occ.note = extra.note;
  await occ.save();

  const goal = await Goal.findById(occ.goal);
  if (goal) {
    const before = goal.progressPercent;
    const evaluation = await recomputeGoal(goal);

    if (status === 'completed' && occ.milestone) {
      await notifyIfMilestoneJustCompleted(user, String(occ.milestone), goal.title);
    }
    return { occurrence: occ.toJSON(), goalProgress: evaluation, previousProgress: before };
  }
  return { occurrence: occ.toJSON() };
}

async function notifyIfMilestoneJustCompleted(user: IUser, milestoneId: string, goalTitle: string) {
  const m = await Milestone.findById(milestoneId);
  if (!m || m.status !== 'completed') return;
  // recomputeMilestones sets completedAt; only celebrate the first time.
  if (m.completedAt && Date.now() - m.completedAt.getTime() > 60_000) return;

  await dispatch({
    user,
    type: 'milestone',
    title: 'Milestone reached',
    body: `You finished "${m.title}" on ${goalTitle}.`,
    data: { milestoneId: String(m._id), type: 'milestone' },
    email: milestoneTemplate(user.name, m.title, goalTitle),
  });
}

export async function reschedule(user: IUser, id: string, date: string) {
  const occ = await owned(user.id, id);
  if (occ.status === 'completed') throw ApiError.badRequest('Completed actions cannot be moved');

  const tz = user.timezone || 'Asia/Kolkata';
  const target = DateTime.fromISO(date, { zone: tz });
  if (!target.isValid) throw ApiError.badRequest('Invalid date');

  const time = DateTime.fromJSDate(occ.scheduledAt).setZone(tz).toFormat('HH:mm');
  const [h, m] = time.split(':').map(Number);

  occ.scheduledDate = localDayStart(target);
  occ.scheduledAt = target.set({ hour: h, minute: m }).toUTC().toJSDate();
  occ.status = 'upcoming';
  occ.reminderSentAt = undefined;
  await occ.save();

  return occ.toJSON();
}
