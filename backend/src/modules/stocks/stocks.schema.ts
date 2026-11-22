import { ConditionStatus } from '@prisma/client';
import { z } from 'zod';

const conditionEnum = z.nativeEnum(ConditionStatus);

export const updateConditionSchema = z
  .object({
    itemId: z.number().int().positive(),
    locationId: z.number().int().positive(),
    fromStatus: conditionEnum,
    toStatus: conditionEnum,
    qty: z.number().int().min(1),
    note: z.string().trim().min(5, 'Catatan kondisi minimal 5 karakter.').max(1000),
    photoUrl: z.string().trim().max(500).optional().nullable(),
    jobCode: z.string().trim().max(255).optional().nullable(),
    expectedVersion: z.number().int().min(1),
  })
  .strict()
  .refine((d) => d.fromStatus !== d.toStatus, {
    message: 'Status kondisi asal dan tujuan harus berbeda.',
    path: ['toStatus'],
  });

export const updateRemarksSchema = z
  .object({
    itemId: z.number().int().positive(),
    locationId: z.number().int().positive(),
    jobCode: z.string().trim().max(255).optional().nullable(),
    remarks: z.string().trim().max(2000).optional().nullable(),
    expectedVersion: z.number().int().min(1),
  })
  .strict();

export const stockInSchema = z
  .object({
    itemId: z.number().int().positive(),
    locationId: z.number().int().positive(),
    qty: z.number().int().min(1),
    note: z.string().trim().min(5, 'Catatan referensi pengadaan minimal 5 karakter.').max(1000),
    jobCode: z.string().trim().max(255).optional().nullable(),
    expectedVersion: z.number().int().min(1).optional(),
  })
  .strict();

export const stockDisposeSchema = z
  .object({
    itemId: z.number().int().positive(),
    locationId: z.number().int().positive(),
    qty: z.number().int().min(1),
    note: z.string().trim().min(10, 'Alasan penghapusan (disposal ISO) minimal 10 karakter.').max(1000),
    expectedVersion: z.number().int().min(1),
  })
  .strict();
