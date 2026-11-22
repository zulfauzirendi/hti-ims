import { Router } from 'express';
import { TransferStatus, UserRole } from '@prisma/client';
import { authenticateJwt } from '../../middlewares/authenticate';
import { authorizeRoles } from '../../middlewares/rbac';
import { requirePasswordChanged } from '../../middlewares/requirePasswordChanged';
import { validateBody, validateParams, validateQuery } from '../../middlewares/validate';
import { idempotencyGuard } from '../../utils/idempotency';
import { sendSuccess } from '../../utils/response';
import {
  cancelTransferSchema,
  createTransferSchema,
  listTransfersQuerySchema,
  receiveTransferSchema,
  rejectTransferSchema,
  transferIdParamSchema,
} from './transfers.schema';
import {
  cancelTransfer,
  createTransfer,
  listTransfers,
  receiveTransfer,
  rejectTransfer,
} from './transfers.service';

export const transfersRouter = Router();

transfersRouter.use(authenticateJwt, requirePasswordChanged);

transfersRouter.get('/', validateQuery(listTransfersQuerySchema), async (req, res, next) => {
  try {
    const q = req.query as unknown as {
      direction: 'incoming' | 'outgoing' | 'all';
      status?: TransferStatus;
      locationId?: number;
      page: number;
      limit: number;
    };
    const result = await listTransfers(q, req.user!);
    sendSuccess(req, res, result.items, 200, result.meta);
  } catch (err) {
    next(err);
  }
});

transfersRouter.post(
  '/',
  authorizeRoles(UserRole.SUPER_ADMIN, UserRole.ADMIN_GUDANG, UserRole.PETUGAS_LAPANGAN),
  idempotencyGuard,
  validateBody(createTransferSchema),
  async (req, res, next) => {
    try {
      const created = await createTransfer(req.body, req.user!);
      sendSuccess(req, res, created, 201);
    } catch (err) {
      next(err);
    }
  }
);

transfersRouter.post(
  '/:id/receive',
  authorizeRoles(UserRole.SUPER_ADMIN, UserRole.ADMIN_GUDANG, UserRole.PETUGAS_LAPANGAN),
  idempotencyGuard,
  validateParams(transferIdParamSchema),
  validateBody(receiveTransferSchema),
  async (req, res, next) => {
    try {
      const result = await receiveTransfer(Number(req.params.id), req.body.receiverNote, req.user!);
      sendSuccess(req, res, result, 200);
    } catch (err) {
      next(err);
    }
  }
);

transfersRouter.post(
  '/:id/reject',
  authorizeRoles(UserRole.SUPER_ADMIN, UserRole.ADMIN_GUDANG, UserRole.PETUGAS_LAPANGAN),
  idempotencyGuard,
  validateParams(transferIdParamSchema),
  validateBody(rejectTransferSchema),
  async (req, res, next) => {
    try {
      const result = await rejectTransfer(Number(req.params.id), req.body.receiverNote, req.user!);
      sendSuccess(req, res, result, 200);
    } catch (err) {
      next(err);
    }
  }
);

transfersRouter.post(
  '/:id/cancel',
  authorizeRoles(UserRole.SUPER_ADMIN, UserRole.ADMIN_GUDANG, UserRole.PETUGAS_LAPANGAN),
  idempotencyGuard,
  validateParams(transferIdParamSchema),
  validateBody(cancelTransferSchema),
  async (req, res, next) => {
    try {
      const result = await cancelTransfer(Number(req.params.id), req.body.senderNote, req.user!);
      sendSuccess(req, res, result, 200);
    } catch (err) {
      next(err);
    }
  }
);
