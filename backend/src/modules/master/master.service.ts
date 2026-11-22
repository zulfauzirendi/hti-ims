import { LocationType, UserRole } from '@prisma/client';
import { logger } from '../../config/logger';
import { prisma } from '../../config/prisma';
import { AppError } from '../../utils/appError';
import { hashPassword } from '../../utils/crypto';

export function listCategories() {
  return prisma.category.findMany({ orderBy: { id: 'asc' } });
}

export function createCategory(input: { code: string; name: string }) {
  return prisma.category.create({ data: { code: input.code.toUpperCase(), name: input.name.toUpperCase() } });
}

export function updateCategory(id: number, input: { name: string }) {
  return prisma.category.update({ where: { id }, data: { name: input.name.toUpperCase() } });
}

export function listLocations(includeInactive = false) {
  return prisma.location.findMany({
    where: includeInactive ? undefined : { isActive: true },
    orderBy: { id: 'asc' },
  });
}

export function createLocation(input: { code: string; name: string; locationType: LocationType }) {
  return prisma.location.create({
    data: { code: input.code.toUpperCase(), name: input.name, locationType: input.locationType, isActive: true },
  });
}

export function updateLocation(
  id: number,
  input: { name?: string; locationType?: LocationType; isActive?: boolean }
) {
  return prisma.location.update({
    where: { id },
    data: {
      ...(input.name !== undefined ? { name: input.name } : {}),
      ...(input.locationType !== undefined ? { locationType: input.locationType } : {}),
      ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
    },
  });
}

export function listUsers() {
  return prisma.user.findMany({
    orderBy: { id: 'asc' },
    select: {
      id: true,
      username: true,
      fullName: true,
      role: true,
      assignedLocationId: true,
      assignedLocation: { select: { id: true, code: true, name: true } },
      mustChangePassword: true,
      isActive: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}

export async function createUser(input: {
  username: string;
  fullName: string;
  password: string;
  role: UserRole;
  assignedLocationId?: number | null;
}) {
  if (input.assignedLocationId) {
    const loc = await prisma.location.findUnique({ where: { id: input.assignedLocationId } });
    if (!loc || !loc.isActive) {
      throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Lokasi penugasan tidak ditemukan.');
    }
  }

  const passwordHash = await hashPassword(input.password);
  return prisma.user.create({
    data: {
      username: input.username,
      fullName: input.fullName,
      passwordHash,
      role: input.role,
      assignedLocationId: input.assignedLocationId ?? null,
      mustChangePassword: true, // Wajib ganti password saat login pertama (SRS-SEC-012)
      isActive: true,
    },
    select: {
      id: true,
      username: true,
      fullName: true,
      role: true,
      assignedLocation: { select: { id: true, code: true, name: true } },
      mustChangePassword: true,
      isActive: true,
      createdAt: true,
    },
  });
}

export async function updateUser(
  targetUserId: number,
  input: {
    fullName?: string;
    role?: UserRole;
    assignedLocationId?: number | null;
    isActive?: boolean;
    resetPassword?: string;
  },
  actorId: number
) {
  const existing = await prisma.user.findUnique({ where: { id: targetUserId } });
  if (!existing) {
    throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Pengguna tidak ditemukan.');
  }

  const nextRole = input.role ?? existing.role;
  const nextLocId =
    input.assignedLocationId !== undefined ? input.assignedLocationId : existing.assignedLocationId;
  const isGlobal = nextRole === UserRole.SUPER_ADMIN || nextRole === UserRole.VIEWER;

  if (isGlobal && nextLocId !== null) {
    throw new AppError(422, 'VALIDATION_ERROR', 'SUPER_ADMIN dan VIEWER tidak boleh memiliki assignedLocationId.');
  }
  if (!isGlobal && nextLocId === null) {
    throw new AppError(422, 'VALIDATION_ERROR', 'ADMIN_GUDANG dan PETUGAS_LAPANGAN wajib memiliki assignedLocationId.');
  }

  const passwordHash = input.resetPassword ? await hashPassword(input.resetPassword) : undefined;
  const shouldRevoke = Boolean(input.resetPassword) || input.isActive === false || input.role !== undefined;

  const updated = await prisma.$transaction(async (tx) => {
    const user = await tx.user.update({
      where: { id: targetUserId },
      data: {
        ...(input.fullName !== undefined ? { fullName: input.fullName } : {}),
        ...(input.role !== undefined ? { role: input.role } : {}),
        ...(input.assignedLocationId !== undefined ? { assignedLocationId: input.assignedLocationId } : {}),
        ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
        ...(passwordHash ? { passwordHash, mustChangePassword: true } : {}),
      },
      select: {
        id: true,
        username: true,
        fullName: true,
        role: true,
        assignedLocation: { select: { id: true, code: true, name: true } },
        mustChangePassword: true,
        isActive: true,
        updatedAt: true,
      },
    });

    if (shouldRevoke) {
      await tx.refreshToken.updateMany({
        where: { userId: targetUserId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }

    return user;
  });

  logger.info(
    { actorId, targetUserId, resetPassword: Boolean(input.resetPassword), roleChanged: input.role !== undefined },
    'SECURITY_AUDIT: User account updated'
  );
  return updated;
}

/**
 * Remote Force-Logout seluruh sesi perangkat aktif (SRS-SEC-011 — mitigasi HP lapangan hilang).
 */
export async function revokeAllUserSessions(targetUserId: number, actorId: number) {
  const existing = await prisma.user.findUnique({ where: { id: targetUserId } });
  if (!existing) {
    throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Pengguna tidak ditemukan.');
  }

  const res = await prisma.refreshToken.updateMany({
    where: { userId: targetUserId, revokedAt: null },
    data: { revokedAt: new Date() },
  });

  logger.warn(
    { actorId, targetUserId, revokedCount: res.count },
    'SECURITY_AUDIT: Super Admin revoked all active sessions for user'
  );
  return { userId: targetUserId, revokedSessions: res.count };
}
