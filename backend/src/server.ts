import { env } from './config/env';
import { logger } from './config/logger';
import { prisma } from './config/prisma';
import { createApp } from './app';

const app = createApp();

const server = app.listen(env.PORT, () => {
  logger.info({ port: env.PORT, env: env.NODE_ENV }, 'HTI-TEIS Backend API listening');
});

async function gracefulShutdown(signal: string) {
  logger.info({ signal }, 'Received shutdown signal — closing HTTP server & DB pool...');
  server.close(async () => {
    await prisma.$disconnect();
    logger.info('Graceful shutdown complete.');
    process.exit(0);
  });
  setTimeout(() => {
    logger.error('Forced shutdown after timeout.');
    process.exit(1);
  }, 10_000).unref();
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
