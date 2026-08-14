import { Router } from 'express';
import { z } from 'zod';
import multer from 'multer';
import { asyncHandler, ok } from '../../utils/http';
import { validate } from '../../middleware/validate';
import { requireAuth } from '../../middleware/auth';
import { User } from '../../models/User';
import { PROGRESS_STYLES, TIME_OF_DAY } from '../../models/enums';
import { ApiError } from '../../utils/ApiError';
import { registerDevice, removeDevice } from '../notifications/notification.service';

const router = Router();
router.use(requireAuth);

const hhmm = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Use HH:mm (24h)');

/**
 * Avatars are kept in memory and stored on the user document as a data URI.
 *
 * Deliberately not written to disk: hosts like Render give each deploy a fresh,
 * ephemeral filesystem, so a disk-backed avatar would silently disappear on the
 * next restart. The client already downscales to 800px at 85% quality, which
 * keeps these well under Mongo's document limit.
 */
// 1MB raw -> ~1.4MB once base64-encoded, which keeps GET /users/me light.
const MAX_AVATAR_BYTES = 1024 * 1024;

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_AVATAR_BYTES },
  fileFilter: (_req, file, cb) =>
    file.mimetype.startsWith('image/')
      ? cb(null, true)
      : cb(ApiError.badRequest('Please choose an image file')),
});

router.get(
  '/me',
  asyncHandler(async (req, res) => ok(res, req.user!.toJSON())),
);

router.patch(
  '/me',
  validate(
    z.object({
      body: z.object({
        name: z.string().min(2).max(80).optional(),
        avatarUrl: z.string().url().optional(),
        mainObjective: z.string().max(200).optional(),
        timezone: z.string().optional(),
      }),
    }),
  ),
  asyncHandler(async (req, res) => {
    const user = await User.findByIdAndUpdate(req.userId, req.body, { new: true });
    ok(res, user?.toJSON(), 'Profile updated');
  }),
);

router.post(
  '/me/avatar',
  upload.single('avatar'),
  asyncHandler(async (req, res) => {
    if (!req.file) throw ApiError.badRequest('Please choose a photo to upload');

    const dataUri = `data:${req.file.mimetype};base64,${req.file.buffer.toString('base64')}`;
    const user = await User.findByIdAndUpdate(
      req.userId,
      { avatarUrl: dataUri },
      { new: true },
    );
    ok(res, { avatarUrl: dataUri, user: user?.toJSON() }, 'Photo updated');
  }),
);

const preferencesBody = z.object({
  preferredDays: z.array(z.number().int().min(0).max(6)).max(7).optional(),
  preferredTimeOfDay: z.enum(TIME_OF_DAY).optional(),
  preferredStartTime: hhmm.optional(),
  defaultSessionMinutes: z.number().int().min(5).max(480).optional(),
  weeklyTargetActions: z.number().int().min(1).max(70).optional(),
  progressStyle: z.enum(PROGRESS_STYLES).optional(),
  constraints: z.array(z.string().max(120)).max(10).optional(),
});

router.get(
  '/me/preferences',
  asyncHandler(async (req, res) => ok(res, req.user!.preferences)),
);

router.patch(
  '/me/preferences',
  validate(z.object({ body: preferencesBody })),
  asyncHandler(async (req, res) => {
    const set = Object.fromEntries(
      Object.entries(req.body).map(([k, v]) => [`preferences.${k}`, v]),
    );
    const user = await User.findByIdAndUpdate(req.userId, { $set: set }, { new: true });
    ok(res, user?.preferences, 'Preferences updated');
  }),
);

const notificationBody = z.object({
  pushEnabled: z.boolean().optional(),
  emailEnabled: z.boolean().optional(),
  actionReminders: z
    .object({ enabled: z.boolean(), minutesBefore: z.number().int().min(0).max(1440) })
    .partial()
    .optional(),
  dailySummary: z.object({ enabled: z.boolean(), time: hhmm }).partial().optional(),
  weeklyDigest: z
    .object({ enabled: z.boolean(), weekday: z.number().int().min(0).max(6), time: hhmm })
    .partial()
    .optional(),
  milestoneAlerts: z.boolean().optional(),
  quietHours: z.object({ enabled: z.boolean(), start: hhmm, end: hhmm }).partial().optional(),
});

router.get(
  '/me/notification-preferences',
  asyncHandler(async (req, res) => ok(res, req.user!.notificationPreference)),
);

router.patch(
  '/me/notification-preferences',
  validate(z.object({ body: notificationBody })),
  asyncHandler(async (req, res) => {
    // Dot-path $set so a partial update never wipes sibling keys.
    const set: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(req.body)) {
      if (v !== null && typeof v === 'object' && !Array.isArray(v)) {
        for (const [ik, iv] of Object.entries(v as object)) {
          set[`notificationPreference.${k}.${ik}`] = iv;
        }
      } else {
        set[`notificationPreference.${k}`] = v;
      }
    }
    const user = await User.findByIdAndUpdate(req.userId, { $set: set }, { new: true });
    ok(res, user?.notificationPreference, 'Notification preferences updated');
  }),
);

router.post(
  '/me/devices',
  validate(
    z.object({
      body: z.object({
        token: z.string().min(10),
        platform: z.enum(['android', 'ios', 'web']).default('android'),
      }),
    }),
  ),
  asyncHandler(async (req, res) => {
    await registerDevice(req.userId!, req.body.token, req.body.platform);
    ok(res, null, 'Device registered for push');
  }),
);

router.delete(
  '/me/devices',
  validate(z.object({ body: z.object({ token: z.string().min(10) }) })),
  asyncHandler(async (req, res) => {
    await removeDevice(req.userId!, req.body.token);
    ok(res, null, 'Device unregistered');
  }),
);

router.delete(
  '/me',
  asyncHandler(async (req, res) => {
    await User.findByIdAndDelete(req.userId);
    ok(res, null, 'Account deleted');
  }),
);

export default router;
