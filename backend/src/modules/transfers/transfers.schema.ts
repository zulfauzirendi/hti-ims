import { ConditionStatus, TransferStatus } from '@prisma/client';
import { z } from 'zod';

export const createTransferSchema = z
  .object({
    itemId: z.number().int().positive(),
    fromLocationId: z.number().int().positive(),
    toLocationId: z.number().int().positive(),
    conditionStatus: z.nativeEnum(ConditionStatus).default(ConditionStatus.GOOD),
    qty: z.number().int().min(1),
    jobCode: z.string().trim().max(255).optional().nullable(),
    senderNote: z.string().trim().min(3, 'Catatan pengiriman minimal 3 karakter.').max(1000),
    expectedVersion: z.number().int().min(1),
  })
  .strict();

export const listTransfersQuerySchema = z.object({
  direction: z.enum(['incoming', 'outgoing', 'all']).default('all'),
  status: z.nativeEnum(TransferStatus).optional(),
  locationId: z.coerce.number().int().positive().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

export const transferIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const receiveTransferSchema = z
  .object({
    receiverNote: z.string().trim().max(1000).optional().nullable(),
  })
  .strict();

export const rejectTransferSchema = z
  .object({
    receiverNote: z.string().trim().min(5, 'Alasan penolakan transfer minimal 5 karakter.').max(1000),
  })
  .strict();

export const cancelTransferSchema = z
  .object({
    senderNote: z.string().trim().max(1000).optional().nullable(),
  })
  .strict();
