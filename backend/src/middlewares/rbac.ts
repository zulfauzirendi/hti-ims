import { NextFunction, Request, Response } from 'express';
import { UserRole } from '@prisma/client';
import { AuthUser } from '../types/express';
import { AppError } from '../utils/appError';

export function authorizeRoles(...allowedRoles: UserRole[]) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const user = req.user;
    if (!user) {
      next(new AppError(401, 'AUTH_TOKEN_EXPIRED', 'Sesi autentikasi diperlukan.'));
      return;
    }
    if (!allowedRoles.includes(user.role)) {
      next(
        new AppError(
          403,
          'RBAC_ROLE_DENIED',
          'Peran akun Anda tidak memiliki izin untuk melakukan operasi ini.'
        )
      );
      return;
    }
    next();
  };
}

/**
 * Penegakan kebijakan Read Global, Write Local (SRS-CAP-003 & SRS-SEC-006).
 * Mencegah IDOR lintas lokasi pada seluruh mutasi stok dan transfer.
 */
export function assertCanWriteLocation(
  user: AuthUser,
  targetLocationId: number,
  options: { allowFieldTech?: boolean } = { allowFieldTech: true }
): void {
  if (user.role === UserRole.SUPER_ADMIN) {
    return;
  }
  if (user.role === UserRole.VIEWER) {
    throw new AppError(403, 'RBAC_ROLE_DENIED', 'Akun Viewer hanya memiliki akses baca.');
  }
  if (user.role === UserRole.PETUGAS_LAPANGAN && options.allowFieldTech === false) {
    throw new AppError(
      403,
      'RBAC_ROLE_DENIED',
      'Operasi ini hanya diizinkan untuk Admin Gudang atau Super Admin.'
    );
  }
  if (user.assignedLocationId !== targetLocationId) {
    throw new AppError(
      403,
      'RBAC_LOCATION_DENIED',
      'Anda hanya berwenang mengubah data pada lokasi tugas Anda.'
    );
  }
}
