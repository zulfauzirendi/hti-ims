import { env } from '../../config/env';
import { logger } from '../../config/logger';
import { prisma } from '../../config/prisma';
import { AppError } from '../../utils/appError';
import {
  generateRefreshToken,
  generateUuid,
  hashPassword,
  sha256Hex,
  signAccessToken,
  verifyPassword,
} from '../../utils/crypto';

function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

export async function loginUser(username: string, password: string, deviceInfo?: string) {
  const user = await prisma.user.findUnique({
    where: { username: username.trim() },
    include: {
      assignedLocation: {
        select: { id: true, code: true, name: true, locationType: true },
      },
    },
  });

  if (!user) {
    logger.warn({ username }, 'Failed login attempt (unknown username)');
    throw new AppError(401, 'AUTH_INVALID_CREDENTIALS', 'Username atau kata sandi salah.');
  }

  const valid = await verifyPassword(user.passwordHash, password);
  if (!valid) {
    logger.warn({ userId: user.id, username }, 'Failed login attempt (invalid password)');
    throw new AppError(401, 'AUTH_INVALID_CREDENTIALS', 'Username atau kata sandi salah.');
  }

  if (!user.isActive) {
    throw new AppError(403, 'AUTH_ACCOUNT_INACTIVE', 'Akun Anda telah dinonaktifkan oleh administrator.');
  }

  const rawRefreshToken = generateRefreshToken();
  const familyId = generateUuid();
  await prisma.refreshToken.create({
    data: {
      userId: user.id,
      familyId,
      tokenHash: sha256Hex(rawRefreshToken),
      deviceInfo: deviceInfo ?? null,
      expiresAt: addDays(new Date(), env.JWT_REFRESH_EXPIRES_DAYS),
    },
  });

  const accessToken = signAccessToken({
    sub: user.id,
    username: user.username,
    role: user.role,
    assignedLocationId: user.assignedLocationId,
  });

  return {
    accessToken,
    refreshToken: rawRefreshToken,
    expiresIn: 900,
    user: {
      id: user.id,
      username: user.username,
      fullName: user.fullName,
      role: user.role,
      mustChangePassword: user.mustChangePassword,
      assignedLocation: user.assignedLocation,
    },
  };
}

export async function refreshSession(rawToken: string, deviceInfo?: string) {
  const tokenHash = sha256Hex(rawToken);
  const record = await prisma.refreshToken.findUnique({
    where: { tokenHash },
    include: { user: true },
  });

  if (!record) {
    throw new AppError(401, 'AUTH_TOKEN_EXPIRED', 'Sesi tidak valid. Silakan login ulang.');
  }

  // REFRESH TOKEN REUSE DETECTION (SRS-SEC-012)
  if (record.revokedAt !== null) {
    await prisma.refreshToken.updateMany({
      where: { userId: record.userId, familyId: record.familyId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    logger.warn(
      { userId: record.userId, familyId: record.familyId },
      'SECURITY_ALERT: Refresh token reuse detected — entire token family revoked'
    );
    throw new AppError(
      401,
      'AUTH_TOKEN_REUSE_DETECTED',
      'Aktivitas sesi mencurigakan terdeteksi. Seluruh sesi telah dicabut, silakan login ulang.'
    );
  }

  if (record.expiresAt < new Date()) {
    throw new AppError(401, 'AUTH_TOKEN_EXPIRED', 'Sesi Anda telah berakhir. Silakan login ulang.');
  }
  if (!record.user.isActive) {
    throw new AppError(403, 'AUTH_ACCOUNT_INACTIVE', 'Akun Anda telah dinonaktifkan.');
  }

  const newRawRefresh = generateRefreshToken();
  await prisma.$transaction([
    prisma.refreshToken.update({
      where: { id: record.id },
      data: { revokedAt: new Date() },
    }),
    prisma.refreshToken.create({
      data: {
        userId: record.userId,
        familyId: record.familyId,
        tokenHash: sha256Hex(newRawRefresh),
        deviceInfo: deviceInfo ?? record.deviceInfo,
        expiresAt: addDays(new Date(), env.JWT_REFRESH_EXPIRES_DAYS),
      },
    }),
  ]);

  const accessToken = signAccessToken({
    sub: record.user.id,
    username: record.user.username,
    role: record.user.role,
    assignedLocationId: record.user.assignedLocationId,
  });

  return {
    accessToken,
    refreshToken: newRawRefresh,
    expiresIn: 900,
  };
}

export async function logoutSession(rawToken: string, userId: number): Promise<void> {
  const tokenHash = sha256Hex(rawToken);
  await prisma.refreshToken.updateMany({
    where: { tokenHash, userId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

export async function changeUserPassword(userId: number, currentPassword: string, newPassword: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) {
    throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Pengguna tidak ditemukan.');
  }

  const valid = await verifyPassword(user.passwordHash, currentPassword);
  if (!valid) {
    throw new AppError(400, 'AUTH_INVALID_CREDENTIALS', 'Kata sandi saat ini tidak sesuai.');
  }

  const newHash = await hashPassword(newPassword);
  await prisma.$transaction([
    prisma.user.update({
      where: { id: userId },
      data: {
        passwordHash: newHash,
        mustChangePassword: false,
      },
    }),
    // Cabut seluruh sesi lama pasca ganti password demi keamanan
    prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    }),
  ]);

  logger.info({ userId }, 'User password updated successfully');
  return { passwordUpdated: true, mustChangePassword: false };
}

export async function getCurrentUserProfile(userId: number) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      username: true,
      fullName: true,
      role: true,
      mustChangePassword: true,
      isActive: true,
      assignedLocation: {
        select: { id: true, code: true, name: true, locationType: true },
      },
    },
  });
  if (!user) {
    throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Pengguna tidak ditemukan.');
  }
  return user;
}
