import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler, ok } from '../../utils/http';
import { validate } from '../../middleware/validate';
import { requireAuth } from '../../middleware/auth';
import { OCCURRENCE_STATUSES } from '../../models/enums';
import * as service from './occurrences.service';
import { materialiseForUser } from './materialiser.service';

const router = Router();
router.use(requireAuth);

router.get(
  '/',
  validate(
    z.object({
      query: z.object({
        from: z.string().optional(),
        to: z.string().optional(),
        status: z.enum(OCCURRENCE_STATUSES).optional(),
      }),
    }),
  ),
  asyncHandler(async (req, res) => {
    const { from, to, status } = req.query as Record<string, string | undefined>;
    ok(res, await service.listRange(req.userId!, req.user!.timezone, from, to, status));
  }),
);

router.get(
  '/today',
  asyncHandler(async (req, res) => {
    ok(res, await service.getToday(req.user!));
  }),
);

router.post(
  '/generate',
  asyncHandler(async (req, res) => {
    // Manual trigger -- useful right after onboarding and in the demo.
    const count = await materialiseForUser(req.user!);
    ok(res, { created: count }, 'Schedule generated');
  }),
);

const completeBody = z.object({
  body: z.object({
    actualMinutes: z.number().int().min(1).max(600).optional(),
    note: z.string().max(500).optional(),
  }),
});

router.post(
  '/:id/complete',
  validate(completeBody),
  asyncHandler(async (req, res) => {
    ok(res, await service.setStatus(req.user!, req.params.id, 'completed', req.body), 'Nice work');
  }),
);

router.post(
  '/:id/start',
  asyncHandler(async (req, res) => {
    ok(res, await service.setStatus(req.user!, req.params.id, 'in_progress'));
  }),
);

router.post(
  '/:id/skip',
  validate(z.object({ body: z.object({ note: z.string().max(500).optional() }) })),
  asyncHandler(async (req, res) => {
    ok(res, await service.setStatus(req.user!, req.params.id, 'skipped', req.body), 'Skipped');
  }),
);

router.post(
  '/:id/undo',
  asyncHandler(async (req, res) => {
    ok(res, await service.setStatus(req.user!, req.params.id, 'upcoming'), 'Reverted');
  }),
);

router.patch(
  '/:id/reschedule',
  validate(z.object({ body: z.object({ date: z.string() }) })),
  asyncHandler(async (req, res) => {
    ok(res, await service.reschedule(req.user!, req.params.id, req.body.date), 'Moved');
  }),
);

export default router;
