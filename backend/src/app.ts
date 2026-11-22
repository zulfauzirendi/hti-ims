import compression from 'compression';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import pinoHttp from 'pino-http';
import { corsOriginList } from './config/env';
import { logger } from './config/logger';
import { globalErrorHandler } from './middlewares/errorHandler';
import { generalApiRateLimiter } from './middlewares/rateLimiter';
import { requestIdMiddleware } from './middlewares/requestId';
import { authRouter } from './modules/auth/auth.routes';
import { dashboardRouter } from './modules/dashboard/dashboard.routes';
import { healthRouter } from './modules/health/health.routes';
import { itemsRouter } from './modules/items/items.routes';
import { logsRouter } from './modules/logs/logs.routes';
import { categoriesRouter, locationsRouter, usersRouter } from './modules/master/master.routes';
import { reportsRouter } from './modules/reports/reports.routes';
import { stocksRouter } from './modules/stocks/stocks.routes';
import { transfersRouter } from './modules/transfers/transfers.routes';
import { uploadsRouter } from './modules/uploads/uploads.routes';

export function createApp() {
  const app = express();

  app.set('trust proxy', 1);
  app.disable('x-powered-by');

  app.use(requestIdMiddleware);
  app.use(
    pinoHttp({
      logger,
      genReqId: (req) => req.requestId,
      customLogLevel: (_req, res, err) => {
        if (err || res.statusCode >= 500) return 'error';
        if (res.statusCode >= 400) return 'warn';
        return 'info';
      },
    })
  );

  // Keamanan HTTP Headers & CORS Whitelist (SRS-SEC-007)
  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'same-origin' },
    })
  );
  app.use(
    cors({
      origin: (origin, callback) => {
        // Klien Desktop/Android native tidak mengirim Origin header; browser divalidasi whitelist
        if (!origin || corsOriginList.includes(origin)) {
          callback(null, true);
          return;
        }
        callback(new Error('Origin tidak diizinkan oleh kebijakan CORS.'));
      },
      credentials: true,
    })
  );

  app.use(compression());
  app.use(express.json({ limit: '1mb' }));
  app.use(generalApiRateLimiter);

  // API v1 Routes
  app.use('/api/v1/health', healthRouter);
  app.use('/api/v1/auth', authRouter);
  app.use('/api/v1/dashboard', dashboardRouter);
  app.use('/api/v1/items', itemsRouter);
  app.use('/api/v1/stocks', stocksRouter);
  app.use('/api/v1/transfers', transfersRouter);
  app.use('/api/v1/uploads', uploadsRouter);
  app.use('/api/v1/logs', logsRouter);
  app.use('/api/v1/reports', reportsRouter);
  app.use('/api/v1/categories', categoriesRouter);
  app.use('/api/v1/locations', locationsRouter);
  app.use('/api/v1/users', usersRouter);

  // 404 Handler
  app.use((req, res) => {
    res.status(404).json({
      success: false,
      error: {
        code: 'RESOURCE_NOT_FOUND',
        message: `Endpoint ${req.method} ${req.originalUrl} tidak ditemukan.`,
      },
      meta: { requestId: req.requestId },
    });
  });

  app.use(globalErrorHandler);
  return app;
}
