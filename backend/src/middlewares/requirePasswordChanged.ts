import { NextFunction, Request, Response } from 'express';
import { AppError } from '../utils/appError';

export function requirePasswordChanged(req: Request, _res: Response, next: NextFunction): void {
  if (req.user?.mustChangePassword) {
    next(
      new AppError(
        403,
        'AUTH_MUST_CHANGE_PASSWORD',
        'Anda wajib mengganti kata sandi terlebih dahulu sebelum mengakses sistem.'
      )
    );
    return;
  }
  next();
}
