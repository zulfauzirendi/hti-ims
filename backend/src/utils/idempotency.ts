import { NextFunction, Request, Response } from 'express';

interface CachedResponse {
  statusCode: number;
  body: unknown;
  expiresAt: number;
}

const TTL_MS = 5 * 60 * 1000; // 5 menit untuk proteksi double-tap / retry jaringan (SRS-SAF-005)
const cache = new Map<string, CachedResponse>();

function pruneExpired(): void {
  const now = Date.now();
  for (const [k, v] of cache.entries()) {
    if (v.expiresAt <= now) cache.delete(k);
  }
}

export function idempotencyGuard(req: Request, res: Response, next: NextFunction): void {
  const rawKey = req.header('X-Idempotency-Key');
  if (!rawKey || rawKey.trim().length < 8) {
    next();
    return;
  }

  pruneExpired();
  const userScope = req.user?.id ?? 'anon';
  const cacheKey = `${userScope}:${req.method}:${req.originalUrl}:${rawKey.trim()}`;
  const hit = cache.get(cacheKey);
  if (hit && hit.expiresAt > Date.now()) {
    res.setHeader('X-Idempotent-Replay', 'true');
    res.status(hit.statusCode).json(hit.body);
    return;
  }

  const originalJson = res.json.bind(res);
  res.json = ((body: unknown) => {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      cache.set(cacheKey, {
        statusCode: res.statusCode,
        body,
        expiresAt: Date.now() + TTL_MS,
      });
    }
    return originalJson(body);
  }) as Response['json'];

  next();
}
