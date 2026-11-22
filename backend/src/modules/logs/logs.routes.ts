import { Router } from 'express';
import { StockActionType } from '@prisma/client';
import { authenticateJwt } from '../../middlewares/authenticate';
import { requirePasswordChanged } from '../../middlewares/requirePasswordChanged';
import { validateQuery } from '../../middlewares/validate';
import { sendSuccess } from '../../utils/response';
import { listLogsQuerySchema } from './logs.schema';
import { listAuditLogs } from './logs.service';

export const logsRouter = Router();

logsRouter.get(
  '/',
  authenticateJwt,
  requirePasswordChanged,
  validateQuery(listLogsQuerySchema),
  async (req, res, next) => {
    try {
      const q = req.query as unknown as {
        itemId?: number;
        locationId?: number;
        actionType?: StockActionType;
        userId?: number;
        dateFrom?: string;
        dateTo?: string;
        page: number;
        limit: number;
      };
      const result = await listAuditLogs(q);
      sendSuccess(req, res, result.items, 200, result.meta);
    } catch (err) {
      next(err);
    }
  }
);
