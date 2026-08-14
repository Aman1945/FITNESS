import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler, created, ok } from '../../utils/http';
import { validate } from '../../middleware/validate';
import { requireAuth } from '../../middleware/auth';
import { Milestone } from '../../models/Milestone';
import { Action } from '../../models/Action';
import { ActionOccurrence } from '../../models/ActionOccurrence';
import { ApiError } from '../../utils/ApiError';
import { ensureGoalOwned } from '../goals/goals.service';
import { recomputeGoal } from '../goals/goal.status.service';

// mergeParams so :goalId from the parent goals router is visible here.
const router = Router({ mergeParams: true });
router.use(requireAuth);

const body = z.object({
  title: z.string().min(2).max(120),
  description: z.string().max(600).optional(),
  order: z.number().int().min(0).default(0),
  targetDate: z.coerce.date().optional(),
});

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const goal = await ensureGoalOwned(req.userId!, req.params.goalId);
    const milestones = await Milestone.find({ goal: goal._id }).sort({ order: 1 });
    ok(res, milestones.map((m) => m.toJSON()));
  }),
);

router.post(
  '/',
  validate(z.object({ body })),
  asyncHandler(async (req, res) => {
    const goal = await ensureGoalOwned(req.userId!, req.params.goalId);
    const count = await Milestone.countDocuments({ goal: goal._id });
    const milestone = await Milestone.create({
      ...req.body,
      order: req.body.order || count,
      goal: goal._id,
      user: req.user!._id,
    });
    created(res, milestone.toJSON(), 'Milestone created');
  }),
);

export default router;

/** Flat routes mounted at /milestones for update/delete/complete. */
export const milestoneItemRouter = Router();
milestoneItemRouter.use(requireAuth);

async function owned(userId: string, id: string) {
  const m = await Milestone.findOne({ _id: id, user: userId });
  if (!m) throw ApiError.notFound('Milestone not found');
  return m;
}

milestoneItemRouter.patch(
  '/:id',
  validate(z.object({ body: body.partial() })),
  asyncHandler(async (req, res) => {
    const m = await owned(req.userId!, req.params.id);
    Object.assign(m, req.body);
    await m.save();
    ok(res, m.toJSON(), 'Milestone updated');
  }),
);

milestoneItemRouter.post(
  '/:id/complete',
  asyncHandler(async (req, res) => {
    const m = await owned(req.userId!, req.params.id);
    m.status = 'completed';
    m.progressPercent = 100;
    m.completedAt = new Date();
    await m.save();

    const goal = await ensureGoalOwned(req.userId!, String(m.goal));
    await recomputeGoal(goal);
    ok(res, m.toJSON(), 'Milestone completed');
  }),
);

milestoneItemRouter.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const m = await owned(req.userId!, req.params.id);
    // Detach children instead of orphaning them.
    await Action.updateMany({ milestone: m._id }, { $unset: { milestone: 1 } });
    await ActionOccurrence.updateMany({ milestone: m._id }, { $unset: { milestone: 1 } });
    await m.deleteOne();
    ok(res, null, 'Milestone deleted');
  }),
);
