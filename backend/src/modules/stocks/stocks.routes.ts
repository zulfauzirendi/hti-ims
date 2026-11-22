import { Router } from 'express';
import { UserRole } from '@prisma/client';
import { authenticateJwt } from '../../middlewares/authenticate';
import { authorizeRoles } from '../../middlewares/rbac';
import { requirePasswordChanged } from '../../middlewares/requirePasswordChanged';
import { validateBody } from '../../middlewares/validate';
import { idempotencyGuard } from '../../utils/idempotency';
import { sendSuccess } from '../../utils/response';
import {
  stockDisposeSchema,
  stockInSchema,
  updateConditionSchema,
  updateRemarksSchema,
} from './stocks.schema';
import {
  disposeBrokenStock,
  recordStockIn,
  updateStockCondition,
  updateStockRemarks,
} from './stocks.service';

export const stocksRouter = Router();

stocksRouter.use(authenticateJwt, requirePasswordChanged);

stocksRouter.post(
  '/update-condition',
  authorizeRoles(UserRole.SUPER_ADMIN, UserRole.ADMIN_GUDANG, UserRole.PETUGAS_LAPANGAN),
  idempotencyGuard,
  validateBody(updateConditionSchema),
  async (req, res, next) => {
    try {
      const updated = await updateStockCondition(req.body, req.user!);
      sendSuccess(req, res, updated, 200);
    } catch (err) {
      next(err);
    }
  }
);

stocksRouter.patch(
  '/remarks',
  authorizeRoles(UserRole.SUPER_ADMIN, UserRole.ADMIN_GUDANG, UserRole.PETUGAS_LAPANGAN),
  validateBody(updateRemarksSchema),
  async (req, res, next) => {
    try {
      const updated = await updateStockRemarks(req.body, req.user!);
      sendSuccess(req, res, updated, 200);
    } catch (err) {
      next(err);
    }
  }
);

stocksRouter.post(
  '/in',
  authorizeRoles(UserRole.SUPER_ADMIN, UserRole.ADMIN_GUDANG),
  idempotencyGuard,
  validateBody(stockInSchema),
  async (req, res, next) => {
    try {
      const updated = await recordStockIn(req.body, req.user!);
      sendSuccess(req, res, updated, 201);
    } catch (err) {
      next(err);
    }
  }
);

stocksRouter.post(
  '/dispose',
  authorizeRoles(UserRole.SUPER_ADMIN),
  idempotencyGuard,
  validateBody(stockDisposeSchema),
  async (req, res, next) => {
    try {
      const updated = await disposeBrokenStock(req.body, req.user!);
      sendSuccess(req, res, updated, 200);
    } catch (err) {
      next(err);
    }
  }
);
