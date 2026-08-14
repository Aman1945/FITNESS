/**
 * Demo seed: one account with three weeks of realistic history.
 *
 * Empty charts ruin a demo video, so this creates goals whose progress genuinely
 * differs -- one ahead, one on track, one drifting -- to exercise every branch of
 * the status algorithm.
 *
 *   npm run seed
 *   login: demo@goalflow.app / Demo1234
 */
import bcrypt from 'bcryptjs';
import { DateTime } from 'luxon';
import { connectDatabase, disconnectDatabase } from './config/db';
import { logger } from './config/logger';
import { User } from './models/User';
import { Goal } from './models/Goal';
import { Milestone } from './models/Milestone';
import { Action } from './models/Action';
import { ActionOccurrence } from './models/ActionOccurrence';
import { WeeklyReflection } from './models/WeeklyReflection';
import { Notification } from './models/Notification';
import { localDayStart, atLocalTime, weekdayIndex } from './utils/date';
import { recomputeGoal } from './modules/goals/goal.status.service';
import { materialiseForUser } from './modules/occurrences/materialiser.service';

const TZ = 'Asia/Kolkata';
const EMAIL = 'demo@goalflow.app';

/** completionRate drives how the goal will be evaluated */
const BLUEPRINT = [
  {
    title: 'Get consistently fit',
    why: 'I want the energy to get through a full day without crashing at 4pm.',
    category: 'health' as const,
    priority: 'high' as const,
    days: [1, 3, 5, 0],
    time: '18:30',
    minutes: 45,
    color: '#10B981',
    completionRate: 0.85, // ahead / on track
    milestones: [
      { title: 'Build the base', actions: ['Warm up and stretch', '45 minute workout'] },
      { title: 'Increase intensity', actions: ['Strength session', 'Cardio session'] },
    ],
  },
  {
    title: 'Learn Spanish',
    why: 'Booked a trip to Madrid in six months and I want to actually talk to people.',
    category: 'learning' as const,
    priority: 'medium' as const,
    days: [1, 2, 3, 4, 5],
    time: '07:30',
    minutes: 25,
    color: '#5B5BD6',
    completionRate: 0.62, // on track / needs attention
    milestones: [
      { title: 'Build basic vocabulary', actions: ['Learn 20 new words', 'Complete one lesson'] },
      { title: 'Improve conversation', actions: ['Practise speaking aloud', 'Review past vocabulary'] },
    ],
  },
  {
    title: 'Read 12 books this year',
    why: 'I keep buying books and never finishing them.',
    category: 'personal' as const,
    priority: 'low' as const,
    days: [2, 4, 6],
    time: '21:00',
    minutes: 30,
    color: '#F59E0B',
    completionRate: 0.34, // behind -- proves the status logic is not cosmetic
    milestones: [{ title: 'Finish the current book', actions: ['Read 20 pages'] }],
  },
];

async function seed() {
  await connectDatabase();

  const existing = await User.findOne({ email: EMAIL });
  if (existing) {
    await Promise.all([
      Goal.deleteMany({ user: existing._id }),
      Milestone.deleteMany({ user: existing._id }),
      Action.deleteMany({ user: existing._id }),
      ActionOccurrence.deleteMany({ user: existing._id }),
      WeeklyReflection.deleteMany({ user: existing._id }),
      Notification.deleteMany({ user: existing._id }),
    ]);
    await existing.deleteOne();
    logger.info('Cleared previous demo data');
  }

  const user = await User.create({
    name: 'Sam Kapoor',
    email: EMAIL,
    passwordHash: await bcrypt.hash('Demo1234', 12),
    timezone: TZ,
    mainObjective: 'Build a healthier, sharper version of myself this year',
    emailVerifiedAt: new Date(),
    onboardingCompleted: true,
    preferences: {
      preferredDays: [1, 2, 3, 4, 5],
      preferredTimeOfDay: 'evening',
      preferredStartTime: '18:30',
      defaultSessionMinutes: 30,
      weeklyTargetActions: 8,
      progressStyle: 'percentage',
      constraints: ['No sessions on Saturday mornings'],
    },
  });

  const today = DateTime.now().setZone(TZ).startOf('day');
  const historyStart = today.minus({ days: 21 });

  for (const bp of BLUEPRINT) {
    const goal = await Goal.create({
      user: user._id,
      title: bp.title,
      why: bp.why,
      description: bp.why,
      category: bp.category,
      priority: bp.priority,
      color: bp.color,
      startDate: historyStart.toJSDate(),
      targetDate: today.plus({ days: 60 }).toJSDate(),
      routine: {
        type: 'specific_days',
        days: bp.days,
        timesPerWeek: bp.days.length,
        timeOfDay: bp.time < '12:00' ? 'morning' : 'evening',
        startTime: bp.time,
        durationMinutes: bp.minutes,
      },
    });

    const actions: { id: unknown; milestone: unknown; title: string }[] = [];
    for (const [i, m] of bp.milestones.entries()) {
      const milestone = await Milestone.create({
        user: user._id,
        goal: goal._id,
        title: m.title,
        order: i,
        targetDate: today.plus({ days: 20 * (i + 1) }).toJSDate(),
      });
      for (const title of m.actions) {
        const action = await Action.create({
          user: user._id,
          goal: goal._id,
          milestone: milestone._id,
          title,
          estimatedMinutes: bp.minutes,
          isRecurring: true,
          recurrence: { type: 'specific_days', days: bp.days, timesPerWeek: bp.days.length },
          preferredTime: bp.time,
        });
        actions.push({ id: action._id, milestone: milestone._id, title });
      }
    }

    // Backfill 21 days of history at this goal's own completion rate.
    const docs = [];
    for (let d = 0; d < 21; d += 1) {
      const day = historyStart.plus({ days: d });
      if (!bp.days.includes(weekdayIndex(day))) continue;

      for (const action of actions) {
        // Deterministic pseudo-random so repeated seeds look the same.
        const roll = ((d * 31 + action.title.length * 17) % 100) / 100;
        const status = roll < bp.completionRate ? 'completed' : roll < bp.completionRate + 0.12 ? 'skipped' : 'missed';
        const at = atLocalTime(day, bp.time);

        docs.push({
          user: user._id,
          action: action.id,
          goal: goal._id,
          milestone: action.milestone,
          scheduledDate: localDayStart(day),
          scheduledAt: at.toUTC().toJSDate(),
          title: action.title,
          estimatedMinutes: bp.minutes,
          priority: bp.priority,
          status,
          completedAt: status === 'completed' ? at.plus({ minutes: bp.minutes }).toJSDate() : undefined,
          actualMinutes: status === 'completed' ? bp.minutes : undefined,
        });
      }
    }
    if (docs.length) await ActionOccurrence.insertMany(docs, { ordered: false });

    await recomputeGoal(goal);
    logger.info({ goal: goal.title, occurrences: docs.length }, 'Seeded goal');
  }

  // Today + the next 7 days come from the real materialiser, not fixtures.
  const created = await materialiseForUser(user);

  // A finished reflection for last week so that screen has history too.
  const lastWeek = today.minus({ weeks: 1 }).startOf('week');
  await WeeklyReflection.create({
    user: user._id,
    weekStart: lastWeek.toUTC().toJSDate(),
    weekEnd: lastWeek.plus({ days: 6 }).endOf('day').toUTC().toJSDate(),
    stats: {
      planned: 14,
      completed: 9,
      missed: 4,
      skipped: 1,
      completionRate: 64,
      goalsWorkedOn: 3,
      strongestGoalTitle: 'Get consistently fit',
      weakestGoalTitle: 'Read 12 books this year',
      minutesInvested: 380,
    },
    wentWell: 'Morning Spanish before work actually stuck. Four days in a row.',
    wasDifficult: 'Evening reading kept losing to being tired.',
    improveNext: 'Move reading to lunch instead of 9pm.',
    submittedAt: lastWeek.plus({ days: 6, hours: 20 }).toJSDate(),
  });

  logger.info({ upcoming: created }, `Seed complete - login ${EMAIL} / Demo1234`);
  await disconnectDatabase();
  process.exit(0);
}

seed().catch(async (err) => {
  logger.error({ err }, 'Seed failed');
  await disconnectDatabase();
  process.exit(1);
});
