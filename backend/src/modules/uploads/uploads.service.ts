import sharp from 'sharp';
import { AppError } from '../../utils/appError';
import { generateUuid } from '../../utils/crypto';
import { storageService } from './local.storage';
import { detectAllowedImageMime } from './magicBytes';

export interface UploadedEvidenceResult {
  filename: string;
  photoUrl: string;
  sizeBytes: number;
  mimeType: 'image/webp';
}

export async function processAndStoreEvidenceImage(rawBuffer: Buffer): Promise<UploadedEvidenceResult> {
  const detectedMime = detectAllowedImageMime(rawBuffer);
  if (!detectedMime) {
    throw new AppError(
      415,
      'UPLOAD_INVALID_MAGIC_BYTES',
      'Format file tidak valid. Hanya gambar JPEG, PNG, atau WebP asli yang diperbolehkan.'
    );
  }

  let safeWebpBuffer: Buffer;
  try {
    // Auto-orient sesuai EXIF lalu re-encode ke WebP bersih (100% metadata EXIF/GPS terhapus — SRS-SEC-011)
    safeWebpBuffer = await sharp(rawBuffer, { failOn: 'error' })
      .rotate()
      .resize(1280, 1280, { fit: 'inside', withoutEnlargement: true })
      .webp({ quality: 80 })
      .toBuffer();
  } catch {
    throw new AppError(
      415,
      'UPLOAD_INVALID_MAGIC_BYTES',
      'Berkas gambar rusak atau tidak dapat diproses dengan aman.'
    );
  }

  const filename = `${generateUuid()}.webp`;
  const photoUrl = await storageService.save(filename, safeWebpBuffer);

  return {
    filename,
    photoUrl,
    sizeBytes: safeWebpBuffer.length,
    mimeType: 'image/webp',
  };
}
