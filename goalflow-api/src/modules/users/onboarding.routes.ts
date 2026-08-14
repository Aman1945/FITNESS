import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler, created, ok } from '../../utils/http';
import { validate } from '../../middleware/validate';
import { requireAuth } from '../../middleware/auth';
import { User } from '../../models/User';
import { Goal } from '../../models/Goal';
import { Action } from '../../models/Action';
import { Milestone } from '../../models/Milestone';
import { GOAL_CATEGORIES, PRIORITIES, PROGRESS_STYLES, TIME_OF_DAY, TIME_OF_DAY_DEFAULTS } from '../../models/enums';
import { routineSchema } from '../goals/goals.schema';
import { materialiseForUser } from '../occurrences/materialiser.service';
import { recomputeGoal } from '../goals/goal.status.service';
import { GOAL_TEMPLATES } from './goal.templates';

const router = Router();
router.use(requireAuth);

/**
 * Onboarding is ONE atomic call.
 * The app collects everything across a few calm screens, then commits once, so a
 * user can never end up half-onboarded with a profile but no goal.
 */
const schema = z.object({
  body: z.object({
    name: z.string().min(2).max(80).optional(),
    avatarUrl: z.string().url().optional(),
    mainObjective: z.string().max(200),
    timezone: z.string().default('Asia/Kolkata'),
    preferences: z.object({
      preferredDays: z.array(z.number().int().min(0).max(6)).min(1).max(7),
      preferredTimeOfDay: z.enum(TIME_OF_DAY),
      preferredStartTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/).optional(),
      defaultSessionMinutes: z.number().int().min(5).max(480).default(30),
      weeklyTargetActions: z.number().int().min(1).max(70).default(5),
      progressStyle: z.enum(PROGRESS_STYLES).default('percentage'),
      constraints: z.array(z.string().max(120)).max(10).default([]),
    }),
    goals: z
      .array(
        z.object({
          title: z.string().min(2).max(120),
          why: z.string().max(500).optional(),
          category: z.enum(GOAL_CATEGORIES).default('personal'),
          customCategory: z.string().max(40).optional(),
          priority: z.enum(PRIORITIES).default('medium'),
          targetDate: z.coerce.date(),
          routine: routineSchema.optional(),
          /** seed the goal from a template (bonus: AI-free smart breakdown) */
          useTemplate: z.boolean().default(true),
        }),
      )
      .min(1)
      .max(3),
  }),
});

router.post(
  '/complete',
  validate(schema),
  asyncHandler(async (req, res) => {
    const body = req.body as z.infer<typeof schema>['body'];
    const user = req.user!;

    const prefs = {
      ...body.preferences,
      preferredStartTime:
        body.preferences.preferredStartTime ??
        TIME_OF_DAY_DEFAULTS[body.preferences.preferredTimeOfDay],
    };

    Object.assign(user, {
      ...(body.name ? { name: body.name } : {}),
      ...(body.avatarUrl ? { avatarUrl: body.avatarUrl } : {}),
      mainObjective: body.mainObjective,
      timezone: body.timezone,
      onboardingCompleted: true,
    });
    user.set('preferences', prefs);
    await user.save();

    const createdGoals = [];
    for (const g of body.goals) {
      // The user's own schedule preferences become the goal's default routine --
      // this is where personalisation actually starts paying off.
      const routine = g.routine ?? {
        type: 'specific_days' as const,
        days: prefs.preferredDays,
        timesPerWeek: prefs.preferredDays.length,
        timeOfDay: prefs.preferredTimeOfDay,
        startTime: prefs.preferredStartTime,
        durationMinutes: prefs.defaultSessionMinutes,
      };

      const goal = await Goal.create({
        user: user._id,
        title: g.title,
        why: g.why,
        category: g.category,
        customCategory: g.customCategory,
        priority: g.priority,
        startDate: new Date(),
        targetDate: g.targetDate,
        routine,
      });

      if (g.useTemplate) await applyTemplate(user._id, goal, prefs.defaultSessionMinutes);
      await recomputeGoal(goal);
      createdGoals.push(goal.toJSON());
    }

    const occurrences = await materialiseForUser(user);

    created(
      res,
      { user: user.toJSON(), goals: createdGoals, scheduledActions: occurrences },
      'You are all set',
    );
  }),
);

/** Suggested milestone/action breakdown so a new goal is never an empty screen. */
async function applyTemplate(
  userId: unknown,
  goal: { _id: unknown; category: string; routine: { days: number[]; startTime: string } },
  sessionMinutes: number,
) {
  const template = GOAL_TEMPLATES[goal.category] ?? GOAL_TEMPLATES.personal;

  for (const [i, m] of template.milestones.entries()) {
    const milestone = await Milestone.create({
      user: userId,
      goal: goal._id,
      title: m.title,
      order: i,
    });

    for (const a of m.actions) {
      await Action.create({
        user: userId,
        goal: goal._id,
        milestone: milestone._id,
        title: a,
        estimatedMinutes: sessionMinutes,
        isRecurring: true,
        recurrence: { type: 'specific_days', days: goal.routine.days, timesPerWeek: goal.routine.days.length },
        preferredTime: goal.routine.startTime,
      });
    }
  }
}

router.get(
  '/templates',
  asyncHandler(async (_req, res) => ok(res, GOAL_TEMPLATES)),
);

export default router;
