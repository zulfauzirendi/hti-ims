import { Request, Response } from 'express';

export interface PaginationMeta {
  page?: number;
  limit?: number;
  total?: number;
  totalPages?: number;
  requestId?: string;
}

export function sendSuccess<T>(
  req: Request,
  res: Response,
  data: T,
  statusCode = 200,
  meta?: Omit<PaginationMeta, 'requestId'>
): Response {
  return res.status(statusCode).json({
    success: true,
    data,
    meta: {
      ...(meta ?? {}),
      requestId: req.requestId,
    },
  });
}
