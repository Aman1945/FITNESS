import { IUser, User } from '../../models/User';
import { Notification } from '../../models/Notification';
import { NotificationType } from '../../models/enums';
import { isWithinQuietHours, nowIn } from '../../utils/date';
import { logger } from '../../config/logger';
import { sendPush } from './push.service';
import { sendEmail } from './email.service';

export interface DispatchInput {
  user: IUser;
  type: NotificationType;
  title: string;
  body: string;
  data?: Record<string, string>;
  email?: { subject: string; html: string };
  /** transactional mail (verification, reset) ignores preferences */
  bypassPreferences?: boolean;
  /**
   * The user explicitly asked for this one (a "send test notification" tap).
   * Still recorded in the feed, but quiet hours and per-type toggles do not
   * apply -- a test that is silently suppressed teaches the user nothing.
   */
  force?: boolean;
}

/**
 * The ONLY way anything leaves the system as a notification.
 * Controllers and jobs never call FCM or Resend directly -- preference checks and
 * quiet hours are enforced here, exactly once (JD section 16).
 */
export async function dispatch(input: DispatchInput) {
  const { user, type, title, body, data = {}, email, bypassPreferences, force } = input;
  const prefs = user.notificationPreference;

  let pushResult: 'sent' | 'failed' | 'skipped' = 'skipped';
  let emailResult: 'sent' | 'failed' | 'skipped' = 'skipped';

  const allowed = bypassPreferences || force || isTypeEnabled(user, type);
  const quiet =
    !bypassPreferences &&
    !force &&
    prefs.quietHours?.enabled &&
    isWithinQuietHours(
      nowIn(user.timezone).toFormat('HH:mm'),
      prefs.quietHours.start,
      prefs.quietHours.end,
    );

  if (allowed && !quiet && prefs.pushEnabled) {
    pushResult = await sendPush(
      user.id,
      user.deviceTokens.map((d) => d.token),
      { title, body, data: { ...data, type } },
    );
  } else if (quiet) {
    logger.debug({ userId: user.id, type }, 'Suppressed by quiet hours');
  }

  if (email && (bypassPreferences || (allowed && prefs.emailEnabled))) {
    emailResult = await sendEmail({ to: user.email, ...email });
  }

  // Transactional mail is not part of the in-app feed.
  if (!bypassPreferences) {
    await Notification.create({
      user: user._id,
      type,
      title,
      body,
      data,
      channels: { push: pushResult, email: emailResult },
    });
  }

  return { push: pushResult, email: emailResult };
}

function isTypeEnabled(user: IUser, type: NotificationType): boolean {
  const p = user.notificationPreference;
  switch (type) {
    case 'action_reminder':
      return p.actionReminders?.enabled ?? true;
    case 'daily_summary':
      return p.dailySummary?.enabled ?? true;
    case 'weekly_digest':
      return p.weeklyDigest?.enabled ?? true;
    case 'milestone':
      return p.milestoneAlerts ?? true;
    default:
      return true;
  }
}

export async function listNotifications(userId: string, limit = 50) {
  return Notification.find({ user: userId }).sort({ createdAt: -1 }).limit(limit);
}

export async function markRead(userId: string, id: string) {
  return Notification.findOneAndUpdate(
    { _id: id, user: userId },
    { readAt: new Date() },
    { new: true },
  );
}

export async function markAllRead(userId: string) {
  await Notification.updateMany(
    { user: userId, readAt: { $exists: false } },
    { readAt: new Date() },
  );
}

export async function registerDevice(
  userId: string,
  token: string,
  platform: 'android' | 'ios' | 'web',
) {
  // Remove first so re-registering the same token does not duplicate.
  await User.updateOne({ _id: userId }, { $pull: { deviceTokens: { token } } });
  await User.updateOne(
    { _id: userId },
    { $push: { deviceTokens: { token, platform, createdAt: new Date() } } },
  );
}

export async function removeDevice(userId: string, token: string) {
  await User.updateOne({ _id: userId }, { $pull: { deviceTokens: { token } } });
}
