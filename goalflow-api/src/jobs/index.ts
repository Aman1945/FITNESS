import cron from 'node-cron';
import { DateTime } from 'luxon';
import { ActionOccurrence } from '../models/ActionOccurrence';
import { User } from '../models/User';
import { logger } from '../config/logger';
import { env } from '../config/env';
import { materialiseAll, markMissedOccurrences } from '../modules/occurrences/materialiser.service';
import { recomputeAllGoals } from '../modules/goals/goal.status.service';
import { dispatch } from '../modules/notifications/notification.service';
import { computeWeekStats } from '../modules/reflections/reflections.service';
import { weeklyDigestTemplate } from '../emails/templates';
import { getToday } from '../modules/occurrences/occurrences.service';

/** Guard so a slow run never overlaps itself on a small dyno. */
function once(name: string, fn: () => Promise<void>) {
  let running = false;
  return async () => {
    if (running) return logger.warn({ job: name }, 'Skipped - previous run still going');
    running = true;
    const t = Date.now();
    try {
      await fn();
      logger.info({ job: name, ms: Date.now() - t }, 'Job finished');
    } catch (err) {
      logger.error({ err, job: name }, 'Job failed');
    } finally {
      running = false;
    }
  };
}

/**
 * Reminders sweep every 15 minutes and compare against each user's LOCAL clock,
 * so one server serves every timezone without per-user cron entries.
 */
const sendActionReminders = once('action-reminders', async () => {
  const users = await User.find({
    onboardingCompleted: true,
    'notificationPreference.pushEnabled': true,
    'notificationPreference.actionReminders.enabled': true,
  });

  for (const user of users) {
    const lead = user.notificationPreference.actionReminders?.minutesBefore ?? 15;
    const now = DateTime.now();
    const due = await ActionOccurrence.find({
      user: user._id,
      status: 'upcoming',
      reminderSentAt: { $exists: false },
      scheduledAt: {
        $gte: now.toJSDate(),
        $lte: now.plus({ minutes: lead }).toJSDate(),
      },
    })
      .populate('goal', 'title')
      .limit(10);

    for (const occ of due) {
      const goal = occ.goal as unknown as { title?: string };
      await dispatch({
        user,
        type: 'action_reminder',
        title: occ.title,
        body: `${occ.estimatedMinutes} min${goal?.title ? ` - ${goal.title}` : ''}. Starting soon.`,
        data: { occurrenceId: String(occ._id), goalId: String(occ.goal), type: 'action_reminder' },
      });
      occ.reminderSentAt = new Date();
      await occ.save();
    }
  }
});

const sendDailySummaries = once('daily-summary', async () => {
  const users = await User.find({
    onboardingCompleted: true,
    'notificationPreference.dailySummary.enabled': true,
  });

  for (const user of users) {
    const local = DateTime.now().setZone(user.timezone || 'Asia/Kolkata');
    const target = user.notificationPreference.dailySummary?.time ?? '08:00';
    // Fires only in the 15-minute bucket that contains the user's chosen time.
    const delta = local.diff(local.startOf('day')).as('minutes') - toMinutes(target);
    if (delta < 0 || delta > 15) continue;

    const today = await getToday(user);
    if (today.summary.planned === 0) continue;

    await dispatch({
      user,
      type: 'daily_summary',
      title: `${today.summary.planned} planned today`,
      body: today.actions
        .slice(0, 3)
        .map((a) => (a as { title: string }).title)
        .join(' - '),
      data: { type: 'daily_summary' },
    });
  }
});

const sendWeeklyDigests = once('weekly-digest', async () => {
  const users = await User.find({
    onboardingCompleted: true,
    'notificationPreference.weeklyDigest.enabled': true,
  });

  for (const user of users) {
    const pref = user.notificationPreference.weeklyDigest;
    const local = DateTime.now().setZone(user.timezone || 'Asia/Kolkata');
    if (local.weekday % 7 !== (pref?.weekday ?? 0)) continue;
    const delta = local.diff(local.startOf('day')).as('minutes') - toMinutes(pref?.time ?? '19:00');
    if (delta < 0 || delta > 30) continue;

    const { stats } = await computeWeekStats(user);
    if (stats.planned === 0) continue;

    await dispatch({
      user,
      type: 'weekly_digest',
      title: 'Your week in review',
      body: `${stats.completed} of ${stats.planned} actions completed (${stats.completionRate}%). Take a minute to reflect.`,
      data: { type: 'weekly_digest', route: '/reflection' },
      email: weeklyDigestTemplate(
        user.name,
        {
          planned: stats.planned,
          completed: stats.completed,
          missed: stats.missed,
          completionRate: stats.completionRate,
          strongest: stats.strongestGoalTitle,
          needsAttention: stats.weakestGoalTitle,
          minutesInvested: stats.minutesInvested,
        },
        `${env.APP_DEEP_LINK}reflection`,
      ),
    });
  }
});

function toMinutes(hhmm: string): number {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
}

/**
 * Optional self-ping for free hosting tiers that sleep on inactivity.
 *
 * Honest limits, which is why this is opt-in rather than on by default:
 *   - It only works while the process is alive. Once the host has already put
 *     the container to sleep, nothing inside it can wake it up again -- the
 *     first request has to come from outside.
 *   - Staying awake around the clock consumes roughly a full month of Render's
 *     750 free instance-hours.
 *
 * An external scheduler (cron-job.org and friends) survives sleeps, restarts and
 * crashes, so prefer that. This exists for the case where you want everything in
 * one place and accept the caveats.
 */
const keepAwake = once('keep-awake', async () => {
  const url = env.KEEP_AWAKE_URL;
  if (!url) return;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 10_000);
  try {
    const res = await fetch(url, {
      signal: controller.signal,
      headers: { 'user-agent': 'goalflow-keepalive' },
    });
    logger.debug({ url, status: res.status }, 'Keep-awake ping');
  } catch (err) {
    // A failed ping is not worth an error-level log; the next one is minutes away.
    logger.debug({ err, url }, 'Keep-awake ping failed');
  } finally {
    clearTimeout(timer);
  }
});

export function startJobs(): void {
  if (env.KEEP_AWAKE_URL) {
    cron.schedule(`*/${env.KEEP_AWAKE_MINUTES} * * * *`, keepAwake);
    logger.info(
      { url: env.KEEP_AWAKE_URL, everyMinutes: env.KEEP_AWAKE_MINUTES },
      'Self-ping enabled - note it cannot wake the service once it has slept',
    );
  }

  if (!env.ENABLE_CRON) {
    logger.warn('Cron disabled (ENABLE_CRON=false)');
    return;
  }

  // Hourly rather than once-a-day so every timezone gets its own local midnight.
  cron.schedule('10 * * * *', once('materialise', materialiseAll));
  cron.schedule('20 * * * *', once('mark-missed', markMissedOccurrences));
  cron.schedule('*/15 * * * *', sendActionReminders);
  cron.schedule('*/15 * * * *', sendDailySummaries);
  cron.schedule('*/30 * * * *', sendWeeklyDigests);
  cron.schedule('0 1 * * *', once('recompute-goals', recomputeAllGoals));

  logger.info('Scheduled jobs started');
}
