import argon2 from 'argon2';
import crypto from 'crypto';
import jwt, { SignOptions } from 'jsonwebtoken';
import { UserRole } from '@prisma/client';
import { env } from '../config/env';

export interface AccessTokenPayload {
  sub: number;
  username: string;
  role: UserRole;
  assignedLocationId: number | null;
}

export async function hashPassword(plainPassword: string): Promise<string> {
  return argon2.hash(plainPassword, {
    type: argon2.argon2id,
    memoryCost: 65536, // 64 MiB (SRS-SEC-001)
    timeCost: 3,
    parallelism: 1,
  });
}

export async function verifyPassword(hash: string, plainPassword: string): Promise<boolean> {
  try {
    return await argon2.verify(hash, plainPassword);
  } catch {
    return false;
  }
}

export function sha256Hex(value: string): string {
  return crypto.createHash('sha256').update(value).digest('hex');
}

export function generateRefreshToken(): string {
  return crypto.randomBytes(48).toString('base64url');
}

export function generateUuid(): string {
  return crypto.randomUUID();
}

export function signAccessToken(payload: AccessTokenPayload): string {
  const options: SignOptions = {
    expiresIn: env.JWT_ACCESS_EXPIRES_IN as SignOptions['expiresIn'],
    algorithm: 'HS256',
  };
  return jwt.sign(
    {
      username: payload.username,
      role: payload.role,
      assignedLocationId: payload.assignedLocationId,
    },
    env.JWT_ACCESS_SECRET,
    { ...options, subject: String(payload.sub) }
  );
}

export function verifyAccessToken(token: string): AccessTokenPayload {
  const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET, { algorithms: ['HS256'] }) as jwt.JwtPayload;
  const sub = Number(decoded.sub);
  if (!Number.isInteger(sub)) {
    throw new Error('Invalid JWT subject');
  }
  return {
    sub,
    username: String(decoded.username),
    role: decoded.role as UserRole,
    assignedLocationId: decoded.assignedLocationId ?? null,
  };
}
