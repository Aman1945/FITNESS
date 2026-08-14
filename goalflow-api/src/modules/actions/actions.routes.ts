import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler, created, ok } from '../../utils/http';
import { validate } from '../../middleware/validate';
import { requireAuth } from '../../middleware/auth';
import { Action } from '../../models/Action';
import { ActionOccurrence } from '../../models/ActionOccurrence';
import { Milestone } from '../../models/Milestone';
import { ApiError } from '../../utils/ApiError';
import { DIFFICULTIES, FREQUENCY_TYPES, PRIORITIES } from '../../models/enums';
import { ensureGoalOwned } from '../goals/goals.service';
import { recomputeGoal } from '../goals/goal.status.service';
import { materialiseForAction } from '../occurrences/materialiser.service';

const router = Router();
router.use(requireAuth);

const hhmm = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Use HH:mm (24h)');

const body = z.object({
  goal: z.string().min(1),
  milestone: z.string().optional(),
  title: z.string().min(2).max(120),
  description: z.string().max(600).optional(),
  estimatedMinutes: z.number().int().min(5).max(480).default(30),
  difficulty: z.enum(DIFFICULTIES).default('medium'),
  priority: z.enum(PRIORITIES).default('medium'),
  isRecurring: z.boolean().default(true),
  recurrence: z
    .object({
      type: z.enum(FREQUENCY_TYPES).default('specific_days'),
      days: z.array(z.number().int().min(0).max(6)).default([]),
      timesPerWeek: z.number().int().min(1).max(7).default(3),
      endDate: z.coerce.date().optional(),
    })
    .default({}),
  dueDate: z.coerce.date().optional(),
  preferredTime: hhmm.optional(),
  targetCount: z.number().int().min(1).optional(),
  unit: z.string().max(20).optional(),
});

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const query: Record<string, unknown> = { user: req.userId, isActive: true };
    if (req.query.goal) query.goal = req.query.goal;
    if (req.query.milestone) query.milestone = req.query.milestone;
    const actions = await Action.find(query).sort({ createdAt: -1 });
    ok(res, actions.map((a) => a.toJSON()));
  }),
);

router.post(
  '/',
  validate(z.object({ body })),
  asyncHandler(async (req, res) => {
    const goal = await ensureGoalOwned(req.userId!, req.body.goal);

    if (req.body.milestone) {
      const m = await Milestone.findOne({ _id: req.body.milestone, goal: goal._id });
      if (!m) throw ApiError.badRequest('Milestone does not belong to this goal');
    }

    const action = await Action.create({ ...req.body, user: req.user!._id, goal: goal._id });

    // Generate the upcoming occurrences immediately so the action shows up on
    // the dashboard right away instead of after the nightly job.
    await materialiseForAction(action, goal, req.user!);
    await recomputeGoal(goal);

    created(res, action.toJSON(), 'Action created');
  }),
);

async function owned(userId: string, id: string) {
  const a = await Action.findOne({ _id: id, user: userId });
  if (!a) throw ApiError.notFound('Action not found');
  return a;
}

router.patch(
  '/:id',
  validate(z.object({ body: body.partial().omit({ goal: true }) })),
  asyncHandler(async (req, res) => {
    const action = await owned(req.userId!, req.params.id);
    Object.assign(action, req.body);
    await action.save();

    const goal = await ensureGoalOwned(req.userId!, String(action.goal));

    // Schedule changes must rewrite the future plan, never the recorded past.
    await ActionOccurrence.deleteMany({
      action: action._id,
      status: 'upcoming',
      scheduledDate: { $gte: new Date(new Date().setHours(0, 0, 0, 0)) },
    });
    await materialiseForAction(action, goal, req.user!);
    await recomputeGoal(goal);

    ok(res, action.toJSON(), 'Action updated');
  }),
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const action = await owned(req.userId!, req.params.id);
    action.isActive = false;
    await action.save();
    // Completed history survives; only the unplayed future is removed.
    await ActionOccurrence.deleteMany({ action: action._id, status: 'upcoming' });
    ok(res, null, 'Action removed');
  }),
);

export default router;
