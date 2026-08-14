import { z } from 'zod';

const password = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .max(72)
  .regex(/[a-zA-Z]/, 'Password must contain a letter')
  .regex(/[0-9]/, 'Password must contain a number');

export const registerSchema = z.object({
  body: z.object({
    name: z.string().min(2).max(80),
    email: z.string().email(),
    password,
    timezone: z.string().default('Asia/Kolkata'),
  }),
});

export const loginSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(1),
    deviceName: z.string().optional(),
  }),
});

export const refreshSchema = z.object({
  body: z.object({ refreshToken: z.string().min(10) }),
});

export const verifyEmailSchema = z.object({
  body: z.object({ email: z.string().email(), code: z.string().length(6) }),
});

export const emailOnlySchema = z.object({
  body: z.object({ email: z.string().email() }),
});

export const resetPasswordSchema = z.object({
  body: z.object({
    token: z.string().min(10),
    newPassword: password,
  }),
});

export const googleSchema = z.object({
  body: z.object({ idToken: z.string().min(20), timezone: z.string().optional() }),
});

export const changePasswordSchema = z.object({
  body: z.object({ currentPassword: z.string().min(1), newPassword: password }),
});
