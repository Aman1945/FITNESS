import { Router } from 'express';
import { asyncHandler, created, ok } from '../../utils/http';
import { validate } from '../../middleware/validate';
import { requireAuth } from '../../middleware/auth';
import * as service from './goals.service';
import { evaluateGoal } from './goal.status.service';
import { createGoalSchema, idParam, listGoalsSchema, updateGoalSchema } from './goals.schema';
import milestoneRouter from '../milestones/milestones.routes';

const router = Router();
router.use(requireAuth);

router.get(
  '/',
  validate(listGoalsSchema),
  asyncHandler(async (req, res) => {
    const goals = await service.listGoals(req.userId!, req.query as never);
    ok(res, goals);
  }),
);

router.post(
  '/',
  validate(createGoalSchema),
  asyncHandler(async (req, res) => {
    const goal = await service.createGoal(req.user!, req.body);
    created(res, goal.toJSON(), 'Goal created');
  }),
);

router.get(
  '/:id',
  validate(idParam),
  asyncHandler(async (req, res) => {
    ok(res, await service.getGoalDetail(req.userId!, req.params.id));
  }),
);

router.patch(
  '/:id',
  validate(updateGoalSchema),
  asyncHandler(async (req, res) => {
    const goal = await service.updateGoal(req.user!, req.params.id, req.body);
    ok(res, goal?.toJSON(), 'Goal updated');
  }),
);

router.delete(
  '/:id',
  validate(idParam),
  asyncHandler(async (req, res) => {
    await service.deleteGoal(req.userId!, req.params.id);
    ok(res, null, 'Goal archived');
  }),
);

for (const [path, status] of [
  ['pause', 'paused'],
  ['resume', 'active'],
  ['complete', 'completed'],
] as const) {
  router.post(
    `/:id/${path}`,
    validate(idParam),
    asyncHandler(async (req, res) => {
      const goal = await service.setGoalStatus(req.user!, req.params.id, status);
      ok(res, goal.toJSON(), `Goal ${path}d`);
    }),
  );
}

router.get(
  '/:id/progress',
  validate(idParam),
  asyncHandler(async (req, res) => {
    const goal = await service.ensureGoalOwned(req.userId!, req.params.id);
    ok(res, await evaluateGoal(goal));
  }),
);

router.get(
  '/:id/history',
  validate(idParam),
  asyncHandler(async (req, res) => {
    const weeks = Number(req.query.weeks ?? 8);
    ok(res, await service.getGoalProgressHistory(req.userId!, req.params.id, weeks));
  }),
);

// Nested: /goals/:goalId/milestones
router.use('/:goalId/milestones', milestoneRouter);

export default router;
