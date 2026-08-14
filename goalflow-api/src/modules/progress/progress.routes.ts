import { Router } from 'express';
import { asyncHandler, ok } from '../../utils/http';
import { requireAuth } from '../../middleware/auth';
import { getConsistency, getSummary } from './progress.service';

const router = Router();
router.use(requireAuth);

router.get(
  '/summary',
  asyncHandler(async (req, res) => {
    const range = (req.query.range as 'week' | 'month' | 'quarter') ?? 'month';
    ok(res, await getSummary(req.user!, range));
  }),
);

router.get(
  '/consistency',
  asyncHandler(async (req, res) => {
    ok(res, await getConsistency(req.user!));
  }),
);

export default router;
