import rateLimit from 'express-rate-limit';
import { env } from '../config/env';

const isTest = env.NODE_ENV === 'test';

// Maks 10 percobaan login / 15 menit per IP+username (SRS-SEC-004)
export const loginRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: isTest ? 1000 : 10,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    const username = typeof req.body?.username === 'string' ? req.body.username.trim().toLowerCase() : '';
    return `${req.ip}:${username}`;
  },
  handler: (req, res) => {
    res.status(429).json({
      success: false,
      error: {
        code: 'RATE_LIMIT_EXCEEDED',
        message: 'Terlalu banyak percobaan login. Silakan coba lagi setelah 15 menit.',
      },
      meta: { requestId: req.requestId },
    });
  },
});

// Maks 120 request / menit per pengguna atau IP (SRS-SEC-004)
export const generalApiRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: isTest ? 5000 : 120,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => (req.user?.id ? `user:${req.user.id}` : `ip:${req.ip}`),
  handler: (req, res) => {
    res.status(429).json({
      success: false,
      error: {
        code: 'RATE_LIMIT_EXCEEDED',
        message: 'Terlalu banyak permintaan dalam 1 menit. Harap tunggu sebentar.',
      },
      meta: { requestId: req.requestId },
    });
  },
});
