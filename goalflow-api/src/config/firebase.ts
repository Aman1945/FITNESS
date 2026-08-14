import admin from 'firebase-admin';
import { env } from './env';
import { logger } from './logger';

let app: admin.app.App | null = null;

/**
 * Firebase is used ONLY for Cloud Messaging (push) and for verifying Google
 * sign-in ID tokens. It is deliberately NOT the source of truth for auth --
 * sessions are owned by this backend (see modules/auth).
 *
 * If credentials are absent the server still boots; push sends become no-ops
 * that are logged, so local development never requires a Firebase project.
 */
export function initFirebase(): void {
  if (app) return;

  const { FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY } = env;
  if (!FIREBASE_PROJECT_ID || !FIREBASE_CLIENT_EMAIL || !FIREBASE_PRIVATE_KEY) {
    logger.warn('Firebase credentials missing - push notifications run in log-only mode');
    return;
  }

  app = admin.initializeApp({
    credential: admin.credential.cert({
      projectId: FIREBASE_PROJECT_ID,
      clientEmail: FIREBASE_CLIENT_EMAIL,
      // Railway/Render store the key with literal \n sequences.
      privateKey: FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    }),
  });
  logger.info('Firebase Admin initialised');
}

export function isFirebaseReady(): boolean {
  return app !== null;
}

export function getMessaging(): admin.messaging.Messaging | null {
  return app ? admin.messaging(app) : null;
}

export function getAuth(): admin.auth.Auth | null {
  return app ? admin.auth(app) : null;
}
