import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const schema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().default(4000),
  API_BASE_URL: z.string().default('http://localhost:4000'),
  APP_DEEP_LINK: z.string().default('goalflow://'),

  MONGODB_URI: z.string().min(1, 'MONGODB_URI is required'),

  JWT_ACCESS_SECRET: z.string().min(16, 'JWT_ACCESS_SECRET too short'),
  JWT_REFRESH_SECRET: z.string().min(16, 'JWT_REFRESH_SECRET too short'),
  ACCESS_TOKEN_TTL: z.string().default('15m'),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().default(30),

  RESEND_API_KEY: z.string().optional(),
  EMAIL_FROM: z.string().default('GoalFlow <onboarding@resend.dev>'),
  EMAIL_DRY_RUN: z
    .string()
    .default('true')
    .transform((v) => v === 'true'),

  FIREBASE_PROJECT_ID: z.string().optional(),
  FIREBASE_CLIENT_EMAIL: z.string().optional(),
  FIREBASE_PRIVATE_KEY: z.string().optional(),

  ENABLE_CRON: z
    .string()
    .default('true')
    .transform((v) => v === 'true'),
  MATERIALISE_DAYS_AHEAD: z.coerce.number().default(7),

  /**
   * Opt-in self-ping to stop a free-tier host sleeping.
   * Must be this service's PUBLIC url -- a loopback request never reaches the
   * host's router, so it does not count as inbound traffic. Leave unset unless
   * you understand the trade-offs (see docs/02-deployment.md).
   */
  KEEP_AWAKE_URL: z.string().url().optional(),
  KEEP_AWAKE_MINUTES: z.coerce.number().min(5).max(30).default(10),
});

const parsed = schema.safeParse(process.env);

if (!parsed.success) {
  // Fail fast: a misconfigured environment must never boot silently.
  console.error('Invalid environment configuration:');
  console.error(parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
export const isProd = env.NODE_ENV === 'production';
