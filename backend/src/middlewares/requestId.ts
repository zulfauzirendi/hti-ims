import { NextFunction, Request, Response } from 'express';
import { generateUuid } from '../utils/crypto';

export function requestIdMiddleware(req: Request, res: Response, next: NextFunction): void {
  const incoming = req.header('X-Request-Id');
  const id = incoming && incoming.trim().length >= 8 && incoming.trim().length <= 64 ? incoming.trim() : generateUuid();
  req.requestId = id;
  res.setHeader('X-Request-Id', id);
  next();
}
