import { Resend } from 'resend';
import { env } from './env';
import { logger } from './logger';

let client: Resend | null = null;

export function getResend(): Resend | null {
  if (client) return client;
  if (!env.RESEND_API_KEY) {
    logger.warn('RESEND_API_KEY missing - emails run in dry-run mode');
    return null;
  }
  client = new Resend(env.RESEND_API_KEY);
  return client;
}

export const emailDryRun = (): boolean => env.EMAIL_DRY_RUN || !env.RESEND_API_KEY;
