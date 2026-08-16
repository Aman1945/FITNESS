import { Router } from 'express';
import { asyncHandler, ok } from '../../utils/http';
import { requireAuth } from '../../middleware/auth';
import { Notification } from '../../models/Notification';
import * as service from './notification.service';

const router = Router();
router.use(requireAuth);

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const [items, unread] = await Promise.all([
      service.listNotifications(req.userId!, Number(req.query.limit ?? 50)),
      Notification.countDocuments({ user: req.userId, readAt: { $exists: false } }),
    ]);
    ok(res, { items: items.map((n) => n.toJSON()), unread });
  }),
);

router.patch(
  '/:id/read',
  asyncHandler(async (req, res) => {
    const n = await service.markRead(req.userId!, req.params.id);
    ok(res, n?.toJSON(), 'Marked read');
  }),
);

router.post(
  '/read-all',
  asyncHandler(async (req, res) => {
    await service.markAllRead(req.userId!);
    ok(res, null, 'All notifications marked read');
  }),
);

/** Send a push to this account's devices -- used to verify setup in the demo. */
router.post(
  '/test',
  asyncHandler(async (req, res) => {
    const result = await service.dispatch({
      user: req.user!,
      type: 'system',
      title: 'GoalFlow',
      body: 'Push notifications are working.',
      data: { type: 'system' },
      // Explicitly requested, so quiet hours must not swallow it.
      force: true,
    });
    ok(res, result, 'Test notification dispatched');
  }),
);

export default router;
