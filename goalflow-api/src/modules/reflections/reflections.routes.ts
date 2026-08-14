import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler, ok } from '../../utils/http';
import { validate } from '../../middleware/validate';
import { requireAuth } from '../../middleware/auth';
import * as service from './reflections.service';

const router = Router();
router.use(requireAuth);

router.get(
  '/current',
  asyncHandler(async (req, res) => {
    ok(res, await service.getCurrentReflection(req.user!));
  }),
);

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const rows = await service.listReflections(req.userId!);
    ok(res, rows.map((r) => r.toJSON()));
  }),
);

router.post(
  '/',
  validate(
    z.object({
      body: z.object({
        wentWell: z.string().max(1000).optional(),
        wasDifficult: z.string().max(1000).optional(),
        improveNext: z.string().max(1000).optional(),
        weekStart: z.string().optional(),
      }),
    }),
  ),
  asyncHandler(async (req, res) => {
    const saved = await service.saveReflection(req.user!, req.body);
    ok(res, saved?.toJSON(), 'Reflection saved');
  }),
);

export default router;
