import fs from 'fs';
import fsp from 'fs/promises';
import path from 'path';
import { Readable } from 'stream';
import { env } from '../../config/env';
import { AppError } from '../../utils/appError';
import { StorageService } from './storage.interface';

const SAFE_FILENAME_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(webp|jpg|png)$/i;

export class LocalVolumeStorage implements StorageService {
  private readonly baseDir: string;

  constructor(baseDir = env.EVIDENCE_STORAGE_DIR) {
    this.baseDir = path.resolve(baseDir);
  }

  private resolveSafePath(filename: string): string {
    if (!SAFE_FILENAME_REGEX.test(filename)) {
      throw new AppError(400, 'VALIDATION_ERROR', 'Nama berkas bukti foto tidak valid.');
    }
    const resolved = path.resolve(this.baseDir, filename);
    if (!resolved.startsWith(this.baseDir + path.sep)) {
      throw new AppError(400, 'VALIDATION_ERROR', 'Akses jalur berkas tidak diizinkan.');
    }
    return resolved;
  }

  async save(filename: string, buffer: Buffer): Promise<string> {
    await fsp.mkdir(this.baseDir, { recursive: true });
    const fullPath = this.resolveSafePath(filename);
    await fsp.writeFile(fullPath, buffer, { mode: 0o640 });
    return `/api/v1/uploads/evidence/${filename}`;
  }

  async exists(filename: string): Promise<boolean> {
    try {
      const fullPath = this.resolveSafePath(filename);
      await fsp.access(fullPath, fs.constants.R_OK);
      return true;
    } catch {
      return false;
    }
  }

  async getReadStream(filename: string): Promise<Readable> {
    const fullPath = this.resolveSafePath(filename);
    try {
      await fsp.access(fullPath, fs.constants.R_OK);
    } catch {
      throw new AppError(404, 'RESOURCE_NOT_FOUND', 'File foto bukti K3 tidak ditemukan.');
    }
    return fs.createReadStream(fullPath);
  }

  async checkHealth(): Promise<boolean> {
    try {
      await fsp.mkdir(this.baseDir, { recursive: true });
      await fsp.access(this.baseDir, fs.constants.R_OK | fs.constants.W_OK);
      return true;
    } catch {
      return false;
    }
  }
}

export const storageService: StorageService = new LocalVolumeStorage();

export function extractEvidenceFilename(photoUrl: string): string | null {
  const prefix = '/api/v1/uploads/evidence/';
  if (!photoUrl.startsWith(prefix)) return null;
  const filename = photoUrl.slice(prefix.length);
  return SAFE_FILENAME_REGEX.test(filename) ? filename : null;
}
