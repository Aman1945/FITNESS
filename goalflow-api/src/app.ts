import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import pinoHttp from 'pino-http';
import { randomUUID } from 'crypto';
import { logger } from './config/logger';
import { errorHandler, notFoundHandler } from './middleware/error';
import { ok } from './utils/http';

import authRoutes from './modules/auth/auth.routes';
import userRoutes from './modules/users/users.routes';
import onboardingRoutes from './modules/users/onboarding.routes';
import goalRoutes from './modules/goals/goals.routes';
import { milestoneItemRouter } from './modules/milestones/milestones.routes';
import actionRoutes from './modules/actions/actions.routes';
import occurrenceRoutes from './modules/occurrences/occurrences.routes';
import progressRoutes from './modules/progress/progress.routes';
import reflectionRoutes from './modules/reflections/reflections.routes';
import notificationRoutes from './modules/notifications/notifications.routes';
import { getDashboard } from './modules/dashboard/dashboard.service';
import { requireAuth } from './middleware/auth';
import { asyncHandler } from './utils/http';

export function createApp() {
  const app = express();

  app.set('trust proxy', 1);
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.use(cors({ origin: true, credentials: true }));
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true }));

  app.use(
    pinoHttp({
      logger,
      genReqId: (req) => (req.headers['x-request-id'] as string) ?? randomUUID(),
      autoLogging: { ignore: (req) => req.url === '/health' },
    }),
  );

  app.get('/health', (_req, res) =>
    res.json({ success: true, data: { status: 'ok', uptime: process.uptime() } }),
  );

  // Root index: opening the base URL in a browser should tell you what this is
  // and where to go, rather than returning a bare 404.
  app.get('/', (_req, res) =>
    ok(res, {
      name: 'GoalFlow API',
      version: '1.0.0',
      status: 'running',
      docs: 'See goalflow-api/README.md',
      baseUrl: '/api/v1',
      demoAccount: { email: 'demo@goalflow.app', password: 'Demo1234' },
      endpoints: {
        auth: [
          'POST /api/v1/auth/register',
          'POST /api/v1/auth/login',
          'POST /api/v1/auth/refresh',
          'POST /api/v1/auth/logout',
          'POST /api/v1/auth/verify-email',
          'POST /api/v1/auth/forgot-password',
          'POST /api/v1/auth/reset-password',
        ],
        user: [
          'GET|PATCH /api/v1/users/me',
          'GET|PATCH /api/v1/users/me/preferences',
          'GET|PATCH /api/v1/users/me/notification-preferences',
          'POST /api/v1/onboarding/complete',
        ],
        goals: [
          'GET|POST /api/v1/goals',
          'GET|PATCH|DELETE /api/v1/goals/:id',
          'POST /api/v1/goals/:id/pause|resume|complete',
          'GET|POST /api/v1/goals/:id/milestones',
          'GET|POST /api/v1/actions',
        ],
        schedule: [
          'GET /api/v1/occurrences?from=&to=',
          'GET /api/v1/occurrences/today',
          'POST /api/v1/occurrences/:id/complete|skip|undo',
        ],
        insights: [
          'GET /api/v1/dashboard',
          'GET /api/v1/progress/summary?range=week|month|quarter',
          'GET /api/v1/reflections/current',
          'GET /api/v1/notifications',
        ],
      },
      note: 'All endpoints except /health, / and /api/v1/auth/* require a Bearer token.',
    }, 'GoalFlow API is running'),
  );

  const api = express.Router();
  api.use('/auth', authRoutes);
  api.use('/users', userRoutes);
  api.use('/onboarding', onboardingRoutes);
  api.use('/goals', goalRoutes);
  api.use('/milestones', milestoneItemRouter);
  api.use('/actions', actionRoutes);
  api.use('/occurrences', occurrenceRoutes);
  api.use('/progress', progressRoutes);
  api.use('/reflections', reflectionRoutes);
  api.use('/notifications', notificationRoutes);

  // Single aggregated payload for the home screen.
  api.get(
    '/dashboard',
    requireAuth,
    asyncHandler(async (req, res) => ok(res, await getDashboard(req.user!))),
  );

  app.use('/api/v1', api);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
