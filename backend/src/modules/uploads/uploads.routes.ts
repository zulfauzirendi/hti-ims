import { Router } from 'express';
import { UserRole } from '@prisma/client';
import multer from 'multer';
import { env } from '../../config/env';
import { authenticateJwt } from '../../middlewares/authenticate';
import { authorizeRoles } from '../../middlewares/rbac';
import { requirePasswordChanged } from '../../middlewares/requirePasswordChanged';
import { AppError } from '../../utils/appError';
import { sendSuccess } from '../../utils/response';
import { storageService } from './local.storage';
import { processAndStoreEvidenceImage } from './uploads.service';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: env.UPLOAD_MAX_MB * 1024 * 1024,
    files: 1,
  },
});

export const uploadsRouter = Router();

// Upload foto bukti K3 ISO 45001 (hanya role yang punya hak tulis)
uploadsRouter.post(
  '/evidence',
  authenticateJwt,
  requirePasswordChanged,
  authorizeRoles(UserRole.SUPER_ADMIN, UserRole.ADMIN_GUDANG, UserRole.PETUGAS_LAPANGAN),
  upload.single('file'),
  async (req, res, next) => {
    try {
      if (!req.file) {
        throw new AppError(400, 'VALIDATION_ERROR', 'File gambar wajib dilampirkan pada field "file".');
      }
      const result = await processAndStoreEvidenceImage(req.file.buffer);
      sendSuccess(req, res, result, 201);
    } catch (err) {
      next(err);
    }
  }
);

// Pengambilan foto bukti K3 wajib terautentikasi JWT (SRS-SEC-008)
uploadsRouter.get(
  '/evidence/:filename',
  authenticateJwt,
  requirePasswordChanged,
  async (req, res, next) => {
    try {
      const filename = req.params.filename ?? '';
      const stream = await storageService.getReadStream(filename);
      const mime = filename.endsWith('.webp')
        ? 'image/webp'
        : filename.endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      res.setHeader('Content-Type', mime);
      res.setHeader('Cache-Control', 'private, max-age=86400');
      res.setHeader('X-Content-Type-Options', 'nosniff');
      stream.pipe(res);
    } catch (err) {
      next(err);
    }
  }
);
