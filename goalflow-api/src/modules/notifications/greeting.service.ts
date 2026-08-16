import { DateTime } from 'luxon';
import { IUser, User } from '../../models/User';
import { ActionOccurrence } from '../../models/ActionOccurrence';
import { Goal } from '../../models/Goal';
import { localDayStart } from '../../utils/date';
import { logger } from '../../config/logger';
import { dispatch } from './notification.service';
import { getConsistency } from '../progress/progress.service';

/**
 * The greeting a user gets when they sign in.
 *
 * It is deliberately NOT one canned "Welcome back" string. A first-ever sign-in,
 * a same-day return and a comeback after three weeks are different moments, and
 * saying the same thing in all three makes the app feel like it isn't paying
 * attention. Copy for a long absence is written to remove guilt rather than add
 * it -- shaming someone on the day they came back is how you lose them again.
 */

export type GreetingKind =
  | 'first_time'
  | 'same_day'
  | 'returning'
  | 'been_a_while'
  | 'long_absence';

export interface Greeting {
  kind: GreetingKind;
  title: string;
  body: string;
}

export function classify(daysAway: number | null): GreetingKind {
  if (daysAway === null) return 'first_time';
  if (daysAway < 1) return 'same_day';
  if (daysAway <= 3) return 'returning';
  if (daysAway <= 14) return 'been_a_while';
  return 'long_absence';
}

interface Context {
  firstName: string;
  daysAway: number | null;
  plannedToday: number;
  completedToday: number;
  streak: number;
  activeGoals: number;
  topGoal?: string;
}

export function buildGreeting(ctx: Context): Greeting {
  const kind = classify(ctx.daysAway);
  const { firstName, plannedToday, completedToday, streak, activeGoals, topGoal } = ctx;
  const remaining = Math.max(0, plannedToday - completedToday);

  switch (kind) {
    case 'first_time':
      return {
        kind,
        title: `Welcome to GoalFlow, ${firstName}`,
        body: activeGoals > 0
          ? 'Your plan is ready. Start with one action today - that is genuinely all it takes.'
          : 'Set your first goal and we will turn it into something you can actually do each day.',
      };

    case 'same_day':
      return {
        kind,
        title: `Hey again, ${firstName}`,
        body: remaining === 0
          ? 'Everything for today is already done. Nothing owed.'
          : `${remaining} thing${remaining === 1 ? '' : 's'} still open today.`,
      };

    case 'returning':
      return {
        kind,
        title: `Welcome back, ${firstName}`,
        body: remaining === 0
          ? streak > 1
            ? `Today is clear, and you are ${streak} days consistent.`
            : 'Nothing scheduled for today. Enjoy it.'
          : `${remaining} action${remaining === 1 ? '' : 's'} planned today${
              topGoal ? `, starting with ${topGoal}.` : '.'
            }`,
      };

    case 'been_a_while':
      return {
        kind,
        title: `Good to see you, ${firstName}`,
        body: `It has been ${ctx.daysAway} days. ${
          remaining > 0
            ? `${remaining} action${remaining === 1 ? '' : 's'} waiting - pick one and you are moving again.`
            : 'Your goals are still here. Open one and pick the next small step.'
        }`,
      };

    case 'long_absence':
      return {
        kind,
        title: `Welcome back, ${firstName}`,
        body: activeGoals > 0
          ? `${ctx.daysAway} days away, and ${activeGoals} goal${
              activeGoals === 1 ? '' : 's'
            } still waiting. No catching up needed - just start from today.`
          : 'Your account is right where you left it. A fresh goal is a good way back in.',
      };
  }
}

/** Gathers the context, stores the greeting, and pushes it if a device exists. */
export async function sendSessionGreeting(user: IUser, previousLogin?: Date | null) {
  try {
    const tz = user.timezone || 'Asia/Kolkata';
    const today = DateTime.now().setZone(tz).startOf('day');

    const daysAway = previousLogin
      ? Math.floor(
          DateTime.now()
            .setZone(tz)
            .diff(DateTime.fromJSDate(previousLogin).setZone(tz), 'days').days,
        )
      : null;

    const [todayRows, activeGoals, consistency] = await Promise.all([
      ActionOccurrence.find({ user: user._id, scheduledDate: localDayStart(today) })
        .select('status title priority')
        .sort({ scheduledAt: 1 }),
      Goal.countDocuments({ user: user._id, status: 'active' }),
      getConsistency(user),
    ]);

    const nextUp = todayRows.find((o) => o.status === 'upcoming');

    const greeting = buildGreeting({
      firstName: user.name.split(' ')[0],
      daysAway,
      plannedToday: todayRows.length,
      completedToday: todayRows.filter((o) => o.status === 'completed').length,
      streak: consistency.currentStreak,
      activeGoals,
      topGoal: nextUp?.title,
    });

    const hasDevice = user.deviceTokens.length > 0;

    await dispatch({
      user,
      type: 'welcome',
      title: greeting.title,
      body: greeting.body,
      data: { type: 'welcome', kind: greeting.kind, route: '/home' },
    });

    // On a brand-new account the app has not registered its FCM token yet, so
    // there is nothing to push to. Flag it and let device registration flush it.
    if (!hasDevice) {
      await User.updateOne({ _id: user._id }, { pendingGreetingAt: new Date() });
    }

    logger.info({ userId: user.id, kind: greeting.kind, daysAway }, 'Session greeting sent');
    return greeting;
  } catch (err) {
    // A greeting must never be able to break signing in.
    logger.error({ err, userId: user.id }, 'Session greeting failed');
    return null;
  }
}

/**
 * Called right after a device registers its push token. If a greeting was stored
 * while the account had no device, push it now instead of silently losing it --
 * that is exactly the first-ever login, the one that matters most.
 */
export async function flushPendingGreeting(userId: string) {
  const user = await User.findById(userId);
  if (!user?.pendingGreetingAt) return;

  // Only worth delivering if it is still fresh; a day-old welcome is noise.
  const ageMinutes = (Date.now() - user.pendingGreetingAt.getTime()) / 60_000;
  await User.updateOne({ _id: userId }, { $unset: { pendingGreetingAt: 1 } });
  if (ageMinutes > 10 || user.deviceTokens.length === 0) return;

  const { Notification } = await import('../../models/Notification');
  const stored = await Notification.findOne({ user: user._id, type: 'welcome' }).sort({
    createdAt: -1,
  });
  if (!stored) return;

  const { sendPush } = await import('./push.service');
  await sendPush(
    user.id,
    user.deviceTokens.map((d) => d.token),
    { title: stored.title, body: stored.body, data: { type: 'welcome', route: '/home' } },
  );
  logger.info({ userId }, 'Flushed pending welcome push after device registration');
}
