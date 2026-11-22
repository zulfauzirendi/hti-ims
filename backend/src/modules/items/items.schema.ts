import { z } from 'zod';

export const ALLOWED_UNITS = ['UNIT', 'PCS', 'SET', 'ROLL', 'EA', 'PAIR', 'BOX', 'BTL'] as const;

export const searchItemsQuerySchema = z.object({
  q: z.string().trim().max(100).optional(),
  categoryId: z.coerce.number().int().positive().optional(),
  locationId: z.coerce.number().int().positive().optional(),
  condition: z.enum(['GOOD', 'SERVICE', 'BROKEN', 'IN_TRANSIT']).optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

export const itemIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const createItemSchema = z
  .object({
    categoryId: z.number().int().positive(),
    description: z.string().trim().min(2).max(255),
    specification: z.string().trim().max(2000).optional().nullable(),
    unit: z.enum(ALLOWED_UNITS),
  })
  .strict();

export const updateItemSchema = z
  .object({
    categoryId: z.number().int().positive().optional(),
    description: z.string().trim().min(2).max(255).optional(),
    specification: z.string().trim().max(2000).optional().nullable(),
    unit: z.enum(ALLOWED_UNITS).optional(),
  })
  .strict();
