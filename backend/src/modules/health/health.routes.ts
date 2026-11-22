import { Router } from 'express';
import { env } from '../../config/env';
import { prisma } from '../../config/prisma';
import { sendSuccess } from '../../utils/response';
import { storageService } from '../uploads/local.storage';

export const healthRouter = Router();

healthRouter.get('/', async (req, res) => {
  let dbUp = false;
  try {
    await prisma.$queryRaw`SELECT 1`;
    dbUp = true;
  } catch {
    dbUp = false;
  }

  const storageUp = await storageService.checkHealth();
  const isHealthy = dbUp && storageUp;

  const payload = {
    status: isHealthy ? 'ok' : 'degraded',
    db: dbUp ? 'up' : 'down',
    storage: storageUp ? 'up' : 'down',
    serverTimeUtc: new Date().toISOString(),
    minClientVersion: env.MIN_CLIENT_VERSION,
    latestClientVersion: env.LATEST_CLIENT_VERSION,
  };

  if (!isHealthy) {
    res.status(503).json({
      success: false,
      data: payload,
      error: {
        code: 'SERVICE_MAINTENANCE',
        message: 'Layanan database atau penyimpanan sedang tidak tersedia.',
      },
      meta: { requestId: req.requestId },
    });
    return;
  }

  sendSuccess(req, res, payload, 200);
});
