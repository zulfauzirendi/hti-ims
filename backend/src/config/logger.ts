import pino from 'pino';
import { env } from './env';

export const logger = pino({
  level: env.NODE_ENV === 'test' ? 'silent' : env.LOG_LEVEL,
  base: { service: 'hti-teis-api' },
  timestamp: pino.stdTimeFunctions.isoTime,
  // Redaksi data sensitif otomatis (SRS-SEC-009)
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers.cookie',
      '*.password',
      '*.currentPassword',
      '*.newPassword',
      '*.passwordHash',
      '*.refreshToken',
      '*.accessToken',
      '*.token',
    ],
    censor: '[REDACTED]',
  },
});
