import bcrypt from 'bcryptjs';
import { IUser, User } from '../../models/User';
import { ApiError } from '../../utils/ApiError';
import { env } from '../../config/env';
import { logger } from '../../config/logger';
import { getAuth } from '../../config/firebase';
import { dispatch } from '../notifications/notification.service';
import { sendSessionGreeting } from '../notifications/greeting.service';
import {
  generateNumericCode,
  generateRefreshToken,
  hashToken,
  signAccessToken,
} from './token.service';
import {
  resetPasswordTemplate,
  verifyEmailTemplate,
} from '../../emails/templates';
import crypto from 'crypto';

const SALT_ROUNDS = 12;
const VERIFY_TTL_MS = 10 * 60 * 1000;
const RESET_TTL_MS = 15 * 60 * 1000;
const MAX_VERIFY_ATTEMPTS = 5;

export interface AuthResult {
  user: IUser;
  accessToken: string;
  refreshToken: string;
}

async function issueSession(
  user: IUser,
  device?: string,
  options: { greet?: boolean } = {},
): Promise<AuthResult> {
  const { token, hash, expiresAt } = generateRefreshToken();

  // Captured BEFORE the update, because the greeting is built from how long the
  // gap was since the previous sign-in.
  const previousLogin = user.lastLoginAt ?? null;

  // Keep the newest 5 sessions; older ones are dropped rather than accumulating.
  await User.updateOne(
    { _id: user._id },
    {
      $push: {
        refreshTokens: {
          $each: [{ tokenHash: hash, expiresAt, createdAt: new Date(), device }],
          $slice: -5,
        },
      },
      $set: { lastActiveAt: new Date(), lastLoginAt: new Date() },
      $inc: { loginCount: 1 },
    },
  );

  // Fire and forget: a greeting must never delay or fail a sign-in.
  if (options.greet !== false) {
    void sendSessionGreeting(user, previousLogin);
  }

  return {
    user,
    accessToken: signAccessToken({ sub: user.id, email: user.email }),
    refreshToken: token,
  };
}

export async function register(input: {
  name: string;
  email: string;
  password: string;
  timezone: string;
}): Promise<AuthResult> {
  const existing = await User.findOne({ email: input.email.toLowerCase() });
  if (existing) throw ApiError.conflict('An account with this email already exists');

  const passwordHash = await bcrypt.hash(input.password, SALT_ROUNDS);
  const code = generateNumericCode();

  const user = await User.create({
    name: input.name,
    email: input.email.toLowerCase(),
    passwordHash,
    timezone: input.timezone,
    emailVerification: {
      codeHash: hashToken(code),
      expiresAt: new Date(Date.now() + VERIFY_TTL_MS),
      attempts: 0,
    },
  });

  const tpl = verifyEmailTemplate(user.name, code);
  await dispatch({
    user,
    type: 'system',
    title: 'Verify your email',
    body: 'We sent you a 6-digit code.',
    email: tpl,
    bypassPreferences: true,
  });

  if (env.NODE_ENV !== 'production') {
    logger.info({ email: user.email, code }, '[dev] verification code');
  }

  return issueSession(user);
}

export async function login(email: string, password: string, device?: string) {
  const user = await User.findOne({ email: email.toLowerCase() }).select('+passwordHash');
  // Same error for unknown email and wrong password -- no account enumeration.
  if (!user?.passwordHash) throw ApiError.unauthorized('Incorrect email or password');

  const valid = await bcrypt.compare(password, user.passwordHash);
  if (!valid) throw ApiError.unauthorized('Incorrect email or password');

  return issueSession(user, device);
}

export async function refresh(refreshToken: string): Promise<AuthResult> {
  const hash = hashToken(refreshToken);
  const user = await User.findOne({ 'refreshTokens.tokenHash': hash }).select(
    '+refreshTokens',
  );
  if (!user) throw ApiError.unauthorized('Invalid refresh token');

  const stored = user.refreshTokens.find((t) => t.tokenHash === hash);
  if (!stored || stored.expiresAt < new Date()) {
    await User.updateOne({ _id: user._id }, { $pull: { refreshTokens: { tokenHash: hash } } });
    throw ApiError.unauthorized('Refresh token expired');
  }

  // Rotation: the presented token is consumed before a new one is issued.
  await User.updateOne({ _id: user._id }, { $pull: { refreshTokens: { tokenHash: hash } } });
  // A token rotation is not a sign-in; greeting here would fire every 15 minutes.
  return issueSession(user, stored.device, { greet: false });
}

export async function logout(userId: string, refreshToken?: string) {
  if (refreshToken) {
    await User.updateOne(
      { _id: userId },
      { $pull: { refreshTokens: { tokenHash: hashToken(refreshToken) } } },
    );
  } else {
    await User.updateOne({ _id: userId }, { $set: { refreshTokens: [] } });
  }
}

export async function verifyEmail(email: string, code: string) {
  const user = await User.findOne({ email: email.toLowerCase() }).select(
    '+emailVerification',
  );
  if (!user) throw ApiError.notFound('Account not found');
  if (user.emailVerifiedAt) return user;

  const v = user.emailVerification;
  if (!v?.codeHash) throw ApiError.badRequest('No verification pending. Request a new code.');
  if (v.attempts >= MAX_VERIFY_ATTEMPTS) {
    throw ApiError.tooMany('Too many attempts. Request a new code.');
  }
  if (v.expiresAt < new Date()) throw ApiError.badRequest('Code expired');

  if (hashToken(code) !== v.codeHash) {
    await User.updateOne({ _id: user._id }, { $inc: { 'emailVerification.attempts': 1 } });
    throw ApiError.badRequest('Incorrect code');
  }

  user.emailVerifiedAt = new Date();
  user.set('emailVerification', undefined);
  await user.save();
  return user;
}

export async function resendVerification(email: string) {
  const user = await User.findOne({ email: email.toLowerCase() });
  if (!user || user.emailVerifiedAt) return; // silent: no enumeration

  const code = generateNumericCode();
  user.set('emailVerification', {
    codeHash: hashToken(code),
    expiresAt: new Date(Date.now() + VERIFY_TTL_MS),
    attempts: 0,
  });
  await user.save();

  await dispatch({
    user,
    type: 'system',
    title: 'Verify your email',
    body: 'We sent a new code.',
    email: verifyEmailTemplate(user.name, code),
    bypassPreferences: true,
  });

  if (env.NODE_ENV !== 'production') logger.info({ email, code }, '[dev] verification code');
}

export async function forgotPassword(email: string) {
  const user = await User.findOne({ email: email.toLowerCase() });
  // Always resolve successfully so the endpoint cannot probe for accounts.
  if (!user) return;

  const token = crypto.randomBytes(32).toString('hex');
  user.set('passwordReset', {
    tokenHash: hashToken(token),
    expiresAt: new Date(Date.now() + RESET_TTL_MS),
  });
  await user.save();

  const url = `${env.APP_DEEP_LINK}reset-password?token=${token}`;
  await dispatch({
    user,
    type: 'system',
    title: 'Reset your password',
    body: 'We emailed you a reset link.',
    email: resetPasswordTemplate(user.name, url, token),
    bypassPreferences: true,
  });

  if (env.NODE_ENV !== 'production') logger.info({ email, token }, '[dev] reset token');
}

export async function resetPassword(token: string, newPassword: string) {
  const user = await User.findOne({ 'passwordReset.tokenHash': hashToken(token) }).select(
    '+passwordReset',
  );
  if (!user || !user.passwordReset || user.passwordReset.expiresAt < new Date()) {
    throw ApiError.badRequest('Reset link is invalid or has expired');
  }

  user.passwordHash = await bcrypt.hash(newPassword, SALT_ROUNDS);
  user.set('passwordReset', undefined);
  // A password change invalidates every existing session.
  user.set('refreshTokens', []);
  await user.save();
}

export async function changePassword(
  userId: string,
  currentPassword: string,
  newPassword: string,
) {
  const user = await User.findById(userId).select('+passwordHash');
  if (!user?.passwordHash) throw ApiError.badRequest('Password login is not enabled');

  const valid = await bcrypt.compare(currentPassword, user.passwordHash);
  if (!valid) throw ApiError.badRequest('Current password is incorrect');

  user.passwordHash = await bcrypt.hash(newPassword, SALT_ROUNDS);
  user.set('refreshTokens', []);
  await user.save();
}

/**
 * Google sign-in: Firebase only VERIFIES the identity. The session that the app
 * carries afterwards is still one of ours.
 */
export async function googleSignIn(idToken: string, timezone?: string): Promise<AuthResult> {
  const auth = getAuth();
  if (!auth) throw ApiError.badRequest('Google sign-in is not configured on this server');

  const decoded = await auth.verifyIdToken(idToken).catch(() => {
    throw ApiError.unauthorized('Invalid Google token');
  });
  if (!decoded.email) throw ApiError.badRequest('Google account has no email');

  let user = await User.findOne({ email: decoded.email.toLowerCase() });
  if (!user) {
    user = await User.create({
      name: decoded.name ?? decoded.email.split('@')[0],
      email: decoded.email.toLowerCase(),
      googleId: decoded.uid,
      avatarUrl: decoded.picture,
      emailVerifiedAt: new Date(),
      timezone: timezone ?? 'Asia/Kolkata',
    });
  } else if (!user.googleId) {
    user.googleId = decoded.uid;
    if (!user.emailVerifiedAt) user.emailVerifiedAt = new Date();
    await user.save();
  }

  return issueSession(user, 'google');
}
