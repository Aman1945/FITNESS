import { DateTime } from 'luxon';
import { ActionOccurrence } from '../../models/ActionOccurrence';
import { Goal } from '../../models/Goal';
import { Milestone } from '../../models/Milestone';
import { Notification } from '../../models/Notification';
import { IUser } from '../../models/User';
import { localDayStart } from '../../utils/date';
import { getConsistency } from '../progress/progress.service';
import { getToday } from '../occurrences/occurrences.service';

/**
 * ONE call powers the entire home screen.
 * The app should open instantly -- chaining five requests on launch is exactly the
 * sluggishness the brief warns against.
 */
export async function getDashboard(user: IUser) {
  const tz = user.timezone || 'Asia/Kolkata';
  const now = DateTime.now().setZone(tz);
  const today = now.startOf('day');

  const [today_, goals, consistency, upcoming, recentlyCompleted, milestones, unread] =
    await Promise.all([
      getToday(user),
      Goal.find({ user: user._id, status: 'active' })
        .select('title category customCategory color priority progressPercent computedStatus statusReason targetDate routine')
        .sort({ priority: -1, targetDate: 1 })
        .limit(10),
      getConsistency(user),
      ActionOccurrence.find({
        user: user._id,
        status: 'upcoming',
        scheduledDate: { $gt: localDayStart(today), $lte: localDayStart(today.plus({ days: 3 })) },
      })
        .populate('goal', 'title color category')
        .sort({ scheduledAt: 1 })
        .limit(5),
      ActionOccurrence.find({ user: user._id, status: 'completed' })
        .populate('goal', 'title color category')
        .sort({ completedAt: -1 })
        .limit(4),
      Milestone.find({ user: user._id, status: { $ne: 'completed' } })
        .populate('goal', 'title color')
        .sort({ targetDate: 1, order: 1 })
        .limit(3),
      Notification.countDocuments({ user: user._id, readAt: { $exists: false } }),
    ]);

  const needsAttention = goals.filter(
    (g) => g.computedStatus === 'behind' || g.computedStatus === 'needs_attention',
  );

  return {
    greeting: buildGreeting(user, now, today_.summary.planned - today_.summary.completed),
    today: today_,
    goals: goals.map((g) => g.toJSON()),
    consistency,
    upcoming: upcoming.map((o) => o.toJSON()),
    recentlyCompleted: recentlyCompleted.map((o) => o.toJSON()),
    milestones: milestones.map((m) => m.toJSON()),
    attention: {
      count: needsAttention.length,
      goals: needsAttention.slice(0, 2).map((g) => ({
        id: g.id,
        title: g.title,
        status: g.computedStatus,
        reason: g.statusReason,
      })),
    },
    unreadNotifications: unread,
    weeklyReflectionDue: isReflectionDue(now, user),
  };
}

/**
 * Personalisation the user can SEE in three seconds: the greeting follows their
 * own preferred working window, not a generic clock.
 */
function buildGreeting(user: IUser, now: DateTime, remaining: number) {
  const hour = now.hour;
  const part =
    hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : hour < 21 ? 'Good evening' : 'Winding down';

  const firstName = user.name.split(' ')[0];
  let line: string;
  if (remaining <= 0) line = 'Everything for today is done. Enjoy the rest of it.';
  else if (remaining === 1) line = 'One thing left today.';
  else line = `${remaining} things left today.`;

  const pref = user.preferences?.preferredTimeOfDay;
  const nudge =
    remaining > 0 && pref === 'morning' && hour >= 12
      ? 'Your usual morning slot has passed - a short version still counts.'
      : undefined;

  return { title: `${part}, ${firstName}`, subtitle: line, nudge };
}

function isReflectionDue(now: DateTime, user: IUser): boolean {
  const weekday = user.notificationPreference?.weeklyDigest?.weekday ?? 0;
  return now.weekday % 7 === weekday || now.weekday === 7;
}
