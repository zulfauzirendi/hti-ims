import { StockActionType } from '@prisma/client';
import { z } from 'zod';

export const listLogsQuerySchema = z.object({
  itemId: z.coerce.number().int().positive().optional(),
  locationId: z.coerce.number().int().positive().optional(),
  actionType: z.nativeEnum(StockActionType).optional(),
  userId: z.coerce.number().int().positive().optional(),
  dateFrom: z.string().datetime({ offset: true }).or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)).optional(),
  dateTo: z.string().datetime({ offset: true }).or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)).optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(25),
});
