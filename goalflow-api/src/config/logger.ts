import pino from 'pino';
import { env, isProd } from './env';

export const logger = pino({
  level: isProd ? 'info' : 'debug',
  transport: isProd
    ? undefined
    : { target: 'pino/file', options: { destination: 1 } },
  base: { service: 'goalflow-api', env: env.NODE_ENV },
  redact: {
    paths: [
      'req.headers.authorization',
      'req.body.password',
      'req.body.newPassword',
      'req.body.currentPassword',
    ],
    censor: '[redacted]',
  },
});
