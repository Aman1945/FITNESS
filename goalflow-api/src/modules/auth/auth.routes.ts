import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { asyncHandler, created, ok } from '../../utils/http';
import { validate } from '../../middleware/validate';
import { requireAuth } from '../../middleware/auth';
import * as service from './auth.service';
import {
  changePasswordSchema,
  emailOnlySchema,
  googleSchema,
  loginSchema,
  refreshSchema,
  registerSchema,
  resetPasswordSchema,
  verifyEmailSchema,
} from './auth.schema';

const router = Router();

// Credential endpoints are rate limited per IP -- cheap brute-force protection.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: { code: 'RATE_LIMITED', message: 'Too many attempts, try again later' } },
});

const shape = (r: Awaited<ReturnType<typeof service.login>>) => ({
  user: r.user.toJSON(),
  accessToken: r.accessToken,
  refreshToken: r.refreshToken,
});

router.post(
  '/register',
  authLimiter,
  validate(registerSchema),
  asyncHandler(async (req, res) => {
    const result = await service.register(req.body);
    created(res, shape(result), 'Account created. Check your email for the code.');
  }),
);

router.post(
  '/login',
  authLimiter,
  validate(loginSchema),
  asyncHandler(async (req, res) => {
    const result = await service.login(req.body.email, req.body.password, req.body.deviceName);
    ok(res, shape(result), 'Signed in');
  }),
);

router.post(
  '/refresh',
  validate(refreshSchema),
  asyncHandler(async (req, res) => {
    const result = await service.refresh(req.body.refreshToken);
    ok(res, shape(result), 'Session refreshed');
  }),
);

router.post(
  '/logout',
  requireAuth,
  asyncHandler(async (req, res) => {
    await service.logout(req.userId!, req.body?.refreshToken);
    ok(res, null, 'Signed out');
  }),
);

router.post(
  '/verify-email',
  authLimiter,
  validate(verifyEmailSchema),
  asyncHandler(async (req, res) => {
    const user = await service.verifyEmail(req.body.email, req.body.code);
    ok(res, user.toJSON(), 'Email verified');
  }),
);

router.post(
  '/resend-code',
  authLimiter,
  validate(emailOnlySchema),
  asyncHandler(async (req, res) => {
    await service.resendVerification(req.body.email);
    ok(res, null, 'If that account exists, a new code is on its way.');
  }),
);

router.post(
  '/forgot-password',
  authLimiter,
  validate(emailOnlySchema),
  asyncHandler(async (req, res) => {
    await service.forgotPassword(req.body.email);
    ok(res, null, 'If that account exists, a reset link is on its way.');
  }),
);

router.post(
  '/reset-password',
  authLimiter,
  validate(resetPasswordSchema),
  asyncHandler(async (req, res) => {
    await service.resetPassword(req.body.token, req.body.newPassword);
    ok(res, null, 'Password updated. Please sign in.');
  }),
);

router.post(
  '/change-password',
  requireAuth,
  validate(changePasswordSchema),
  asyncHandler(async (req, res) => {
    await service.changePassword(req.userId!, req.body.currentPassword, req.body.newPassword);
    ok(res, null, 'Password changed. Please sign in again.');
  }),
);

router.post(
  '/google',
  validate(googleSchema),
  asyncHandler(async (req, res) => {
    const result = await service.googleSignIn(req.body.idToken, req.body.timezone);
    ok(res, shape(result), 'Signed in with Google');
  }),
);

export default router;
