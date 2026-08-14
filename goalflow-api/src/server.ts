import { createApp } from './app';
import { env } from './config/env';
import { logger } from './config/logger';
import { connectDatabase, disconnectDatabase } from './config/db';
import { initFirebase } from './config/firebase';
import { startJobs } from './jobs';

async function bootstrap() {
  await connectDatabase();
  initFirebase();

  const app = createApp();
  const server = app.listen(env.PORT, () => {
    logger.info(`GoalFlow API listening on ${env.API_BASE_URL} (${env.NODE_ENV})`);
  });

  startJobs();

  const shutdown = async (signal: string) => {
    logger.info({ signal }, 'Shutting down');
    server.close(async () => {
      await disconnectDatabase();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10_000).unref();
  };

  process.on('SIGTERM', () => void shutdown('SIGTERM'));
  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('unhandledRejection', (err) => logger.error({ err }, 'Unhandled rejection'));
}

bootstrap().catch((err) => {
  logger.error({ err }, 'Failed to start server');
  process.exit(1);
});
