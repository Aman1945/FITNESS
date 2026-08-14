import { getMessaging, isFirebaseReady } from '../../config/firebase';
import { logger } from '../../config/logger';
import { User } from '../../models/User';

export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

/**
 * Firebase Cloud Messaging fan-out.
 * Invalid/expired device tokens are pruned automatically so the collection does
 * not rot over time.
 */
export async function sendPush(
  userId: string,
  tokens: string[],
  payload: PushPayload,
): Promise<'sent' | 'failed' | 'skipped'> {
  if (!tokens.length) return 'skipped';

  const messaging = getMessaging();
  if (!isFirebaseReady() || !messaging) {
    logger.info({ userId, payload }, '[push:log-only] Firebase not configured');
    return 'skipped';
  }

  try {
    const res = await messaging.sendEachForMulticast({
      tokens,
      notification: { title: payload.title, body: payload.body },
      data: payload.data ?? {},
      android: { priority: 'high', notification: { channelId: 'goalflow_default' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });

    const stale: string[] = [];
    res.responses.forEach((r, i) => {
      const code = r.error?.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-argument'
      ) {
        stale.push(tokens[i]);
      }
    });

    if (stale.length) {
      await User.updateOne(
        { _id: userId },
        { $pull: { deviceTokens: { token: { $in: stale } } } },
      );
      logger.info({ userId, count: stale.length }, 'Pruned stale device tokens');
    }

    return res.successCount > 0 ? 'sent' : 'failed';
  } catch (err) {
    logger.error({ err, userId }, 'Push send failed');
    return 'failed';
  }
}
