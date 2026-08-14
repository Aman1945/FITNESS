import { emailDryRun, getResend } from '../../config/resend';
import { env } from '../../config/env';
import { logger } from '../../config/logger';

export interface EmailPayload {
  to: string;
  subject: string;
  html: string;
}

/**
 * Single exit point for every outbound email (Resend).
 * In dry-run mode the message is logged instead of sent, so the whole app can be
 * demoed without a verified sending domain.
 */
export async function sendEmail(payload: EmailPayload): Promise<'sent' | 'failed' | 'skipped'> {
  if (emailDryRun()) {
    logger.info(
      { to: payload.to, subject: payload.subject },
      '[email:dry-run] not sent - set EMAIL_DRY_RUN=false to deliver',
    );
    return 'skipped';
  }

  const resend = getResend();
  if (!resend) return 'skipped';

  try {
    const { error } = await resend.emails.send({
      from: env.EMAIL_FROM,
      to: payload.to,
      subject: payload.subject,
      html: payload.html,
    });
    if (error) {
      logger.error({ err: error, to: payload.to }, 'Resend rejected email');
      return 'failed';
    }
    logger.info({ to: payload.to, subject: payload.subject }, 'Email sent');
    return 'sent';
  } catch (err) {
    logger.error({ err, to: payload.to }, 'Email send threw');
    return 'failed';
  }
}
