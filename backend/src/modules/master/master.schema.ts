import { LocationType, UserRole } from '@prisma/client';
import { z } from 'zod';
import { passwordPolicySchema } from '../auth/auth.schema';

export const idParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const createCategorySchema = z
  .object({
    code: z
      .string()
      .trim()
      .min(2)
      .max(10)
      .regex(/^[A-Z0-9]+$/, 'Kode kategori harus huruf besar/angka tanpa spasi.'),
    name: z.string().trim().min(2).max(100),
  })
  .strict();

export const updateCategorySchema = z
  .object({
    name: z.string().trim().min(2).max(100),
  })
  .strict();

export const createLocationSchema = z
  .object({
    code: z
      .string()
      .trim()
      .min(2)
      .max(20)
      .regex(/^[A-Z0-9-]+$/, 'Kode lokasi hanya boleh huruf besar, angka, dan tanda hubung.'),
    name: z.string().trim().min(2).max(100),
    locationType: z.nativeEnum(LocationType).default(LocationType.WAREHOUSE),
  })
  .strict();

export const updateLocationSchema = z
  .object({
    name: z.string().trim().min(2).max(100).optional(),
    locationType: z.nativeEnum(LocationType).optional(),
    isActive: z.boolean().optional(),
  })
  .strict();

export const createUserSchema = z
  .object({
    username: z
      .string()
      .trim()
      .min(3)
      .max(50)
      .regex(/^[a-zA-Z0-9._-]+$/, 'Username hanya boleh huruf, angka, titik, garis bawah, atau tanda hubung.'),
    fullName: z.string().trim().min(2).max(100),
    password: passwordPolicySchema,
    role: z.nativeEnum(UserRole),
    assignedLocationId: z.number().int().positive().nullable().optional(),
  })
  .strict()
  .superRefine((data, ctx) => {
    const isGlobal = data.role === UserRole.SUPER_ADMIN || data.role === UserRole.VIEWER;
    if (isGlobal && data.assignedLocationId != null) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['assignedLocationId'],
        message: 'Role SUPER_ADMIN dan VIEWER tidak boleh terikat pada satu lokasi (harus null).',
      });
    }
    if (!isGlobal && data.assignedLocationId == null) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['assignedLocationId'],
        message: 'Role ADMIN_GUDANG dan PETUGAS_LAPANGAN wajib memiliki assignedLocationId.',
      });
    }
  });

export const updateUserSchema = z
  .object({
    fullName: z.string().trim().min(2).max(100).optional(),
    role: z.nativeEnum(UserRole).optional(),
    assignedLocationId: z.number().int().positive().nullable().optional(),
    isActive: z.boolean().optional(),
    resetPassword: passwordPolicySchema.optional(),
  })
  .strict();
