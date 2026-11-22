import { z } from 'zod';

export const passwordPolicySchema = z
  .string()
  .min(8, 'Kata sandi minimal 8 karakter.')
  .max(128, 'Kata sandi maksimal 128 karakter.')
  .regex(/[A-Z]/, 'Kata sandi wajib mengandung minimal 1 huruf besar.')
  .regex(/[a-z]/, 'Kata sandi wajib mengandung minimal 1 huruf kecil.')
  .regex(/[0-9]/, 'Kata sandi wajib mengandung minimal 1 angka.');

export const loginSchema = z
  .object({
    username: z.string().trim().min(3).max(50),
    password: z.string().min(1).max(128),
    deviceInfo: z.string().trim().max(150).optional(),
  })
  .strict();

export const refreshSchema = z
  .object({
    refreshToken: z.string().trim().min(32),
    deviceInfo: z.string().trim().max(150).optional(),
  })
  .strict();

export const logoutSchema = z
  .object({
    refreshToken: z.string().trim().min(32),
  })
  .strict();

export const changePasswordSchema = z
  .object({
    currentPassword: z.string().min(1).max(128),
    newPassword: passwordPolicySchema,
  })
  .strict()
  .refine((data) => data.currentPassword !== data.newPassword, {
    message: 'Kata sandi baru tidak boleh sama dengan kata sandi lama.',
    path: ['newPassword'],
  });
