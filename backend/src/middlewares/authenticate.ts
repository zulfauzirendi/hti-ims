import { NextFunction, Request, Response } from 'express';
import { prisma } from '../config/prisma';
import { AppError } from '../utils/appError';
import { verifyAccessToken } from '../utils/crypto';

export async function authenticateJwt(req: Request, _res: Response, next: NextFunction): Promise<void> {
  try {
    const header = req.header('Authorization');
    if (!header || !header.startsWith('Bearer ')) {
      throw new AppError(401, 'AUTH_TOKEN_EXPIRED', 'Token autentikasi tidak ditemukan.');
    }

    const token = header.slice(7).trim();
    if (!token) {
      throw new AppError(401, 'AUTH_TOKEN_EXPIRED', 'Token autentikasi kosong.');
    }

    let payload;
    try {
      payload = verifyAccessToken(token);
    } catch {
      throw new AppError(401, 'AUTH_TOKEN_EXPIRED', 'Token autentikasi tidak valid atau telah kedaluwarsa.');
    }

    // Verifikasi live status akun di DB agar Remote Force-Logout / nonaktifkan akun berlaku instan (SRS-SEC-011)
    const user = await prisma.user.findUnique({
      where: { id: payload.sub },
      select: {
        id: true,
        username: true,
        fullName: true,
        role: true,
        assignedLocationId: true,
        mustChangePassword: true,
        isActive: true,
      },
    });

    if (!user) {
      throw new AppError(401, 'AUTH_TOKEN_EXPIRED', 'Pengguna tidak ditemukan.');
    }
    if (!user.isActive) {
      throw new AppError(403, 'AUTH_ACCOUNT_INACTIVE', 'Akun Anda telah dinonaktifkan oleh administrator.');
    }

    req.user = {
      id: user.id,
      username: user.username,
      fullName: user.fullName,
      role: user.role,
      assignedLocationId: user.assignedLocationId,
      mustChangePassword: user.mustChangePassword,
    };

    next();
  } catch (err) {
    next(err);
  }
}
