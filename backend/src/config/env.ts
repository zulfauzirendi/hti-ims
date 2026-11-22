import dotenv from 'dotenv';
import path from 'path';
import { z } from 'zod';

dotenv.config({ path: path.resolve(process.cwd(), '../.env') });
dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  TZ: z.string().default('Asia/Jakarta'),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  DATABASE_URL: z.string().min(1, 'DATABASE_URL wajib diisi'),
  DIRECT_DATABASE_URL: z.string().optional(),
  JWT_ACCESS_SECRET: z.string().min(32, 'JWT_ACCESS_SECRET minimal 32 karakter (>= 256-bit)'),
  JWT_REFRESH_SECRET: z.string().min(32, 'JWT_REFRESH_SECRET minimal 32 karakter (>= 256-bit)'),
  JWT_ACCESS_EXPIRES_IN: z.string().default('15m'),
  JWT_REFRESH_EXPIRES_DAYS: z.coerce.number().int().min(1).max(90).default(7),
  CORS_ORIGINS: z.string().default('http://localhost:3000'),
  STORAGE_DRIVER: z.enum(['local']).default('local'),
  EVIDENCE_STORAGE_DIR: z.string().default(path.resolve(process.cwd(), 'storage/evidence')),
  UPLOAD_MAX_MB: z.coerce.number().positive().max(10).default(2),
  MIN_CLIENT_VERSION: z.string().default('1.0.0'),
  LATEST_CLIENT_VERSION: z.string().default('1.0.0'),
});

export type AppEnv = z.infer<typeof envSchema>;

function loadEnv(): AppEnv {
  const parsed = envSchema.safeParse(process.env);
  if (!parsed.success) {
    console.error('[CONFIG] Validasi environment gagal (fail-fast):', parsed.error.flatten().fieldErrors);
    process.exit(1);
  }
  if (parsed.data.JWT_ACCESS_SECRET === parsed.data.JWT_REFRESH_SECRET) {
    console.error('[CONFIG] JWT_ACCESS_SECRET dan JWT_REFRESH_SECRET harus berbeda (SRS-SEC-003).');
    process.exit(1);
  }
  return parsed.data;
}

export const env: AppEnv = loadEnv();
export const corsOriginList: string[] = env.CORS_ORIGINS.split(',')
  .map((s) => s.trim())
  .filter(Boolean);
