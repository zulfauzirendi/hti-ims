import { NextFunction, Request, Response } from 'express';
import { Prisma } from '@prisma/client';
import multer from 'multer';
import { ZodError } from 'zod';
import { env } from '../config/env';
import { logger } from '../config/logger';
import { AppError } from '../utils/appError';

export function globalErrorHandler(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction
): Response {
  const requestId = req.requestId;

  if (err instanceof AppError) {
    if (err.statusCode === 403 || err.statusCode === 401) {
      logger.warn({ requestId, code: err.code, userId: req.user?.id, path: req.originalUrl }, err.message);
    }
    return res.status(err.statusCode).json({
      success: false,
      error: {
        code: err.code,
        message: err.message,
        ...(err.details !== undefined ? { details: err.details } : {}),
      },
      meta: { requestId },
    });
  }

  if (err instanceof ZodError) {
    const details = err.issues.map((issue) => ({
      field: issue.path.join('.'),
      message: issue.message,
    }));
    return res.status(422).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Data masukan tidak valid. Periksa kembali formulir Anda.',
        details,
      },
      meta: { requestId },
    });
  }

  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({
        success: false,
        error: {
          code: 'UPLOAD_FILE_TOO_LARGE',
          message: `Ukuran file foto melebihi batas maksimal ${env.UPLOAD_MAX_MB} MB.`,
        },
        meta: { requestId },
      });
    }
    return res.status(400).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        message: `Gagal mengunggah file: ${err.message}`,
      },
      meta: { requestId },
    });
  }

  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    if (err.code === 'P2002') {
      return res.status(409).json({
        success: false,
        error: {
          code: 'DUPLICATE_RESOURCE',
          message: 'Data unik sudah terdaftar di sistem.',
        },
        meta: { requestId },
      });
    }
    if (err.code === 'P2025') {
      return res.status(404).json({
        success: false,
        error: {
          code: 'RESOURCE_NOT_FOUND',
          message: 'Data yang diminta tidak ditemukan.',
        },
        meta: { requestId },
      });
    }
  }

  logger.error({ err, requestId, path: req.originalUrl, userId: req.user?.id }, 'Unhandled server error');

  return res.status(500).json({
    success: false,
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message: 'Terjadi kesalahan internal server. Silakan hubungi administrator dengan menyertakan Request ID.',
    },
    meta: { requestId },
  });
}
