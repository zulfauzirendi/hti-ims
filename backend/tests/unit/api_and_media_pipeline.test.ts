import fs from 'fs/promises';
import os from 'os';
import path from 'path';
import sharp from 'sharp';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { createApp } from '../../src/app';
import { LocalVolumeStorage } from '../../src/modules/uploads/local.storage';
import { processAndStoreEvidenceImage } from '../../src/modules/uploads/uploads.service';

describe('HTTP Pipeline & Evidence Media Security Tests', () => {
  const app = createApp();

  it('sets Helmet security headers and propagates X-Request-Id', async () => {
    const reqId = '11111111-2222-4333-8444-555555555555';
    const res = await request(app).get('/api/v1/does-not-exist').set('X-Request-Id', reqId);

    expect(res.status).toBe(404);
    expect(res.headers['x-request-id']).toBe(reqId);
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['x-powered-by']).toBeUndefined();
    expect(res.body).toEqual({
      success: false,
      error: {
        code: 'RESOURCE_NOT_FOUND',
        message: 'Endpoint GET /api/v1/does-not-exist tidak ditemukan.',
      },
      meta: { requestId: reqId },
    });
  });

  it('rejects unauthenticated access to protected endpoints and evidence photos with 401', async () => {
    const resItems = await request(app).get('/api/v1/items/search');
    expect(resItems.status).toBe(401);
    expect(resItems.body.error.code).toBe('AUTH_TOKEN_EXPIRED');

    const resPhoto = await request(app).get(
      '/api/v1/uploads/evidence/123e4567-e89b-12d3-a456-426614174000.webp'
    );
    expect(resPhoto.status).toBe(401);
    expect(resPhoto.body.error.code).toBe('AUTH_TOKEN_EXPIRED');
  });

  it('rejects malformed login payload with 422 VALIDATION_ERROR', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({
      username: 'a',
      password: '',
      injectedField: 'evil',
    });

    expect(res.status).toBe(422);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('re-encodes uploaded JPEG to WebP and strips EXIF metadata (SRS-SEC-011)', async () => {
    // Buat JPEG asli berukuran 100x100 dengan metadata EXIF dummy
    const jpegWithExif = await sharp({
      create: { width: 100, height: 100, channels: 3, background: { r: 211, g: 47, b: 47 } },
    })
      .withExif({ IFD0: { Make: 'SecretCamera', Model: 'SiteGPSPhone' } })
      .jpeg()
      .toBuffer();

    const metaBefore = await sharp(jpegWithExif).metadata();
    expect(metaBefore.exif).toBeDefined();

    const result = await processAndStoreEvidenceImage(jpegWithExif);
    expect(result.mimeType).toBe('image/webp');
    expect(result.filename).toMatch(/^[0-9a-f-]{36}\.webp$/);
    expect(result.photoUrl).toBe(`/api/v1/uploads/evidence/${result.filename}`);

    // Verifikasi hasil file WebP tersimpan dan EXIF sudah 100% terhapus
    const savedPath = path.resolve(process.cwd(), 'storage/evidence', result.filename);
    const savedBytes = await fs.readFile(savedPath);
    const metaAfter = await sharp(savedBytes).metadata();
    expect(metaAfter.format).toBe('webp');
    expect(metaAfter.exif).toBeUndefined();

    await fs.rm(savedPath, { force: true });
  });

  it('blocks path traversal inside LocalVolumeStorage', async () => {
    const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'hti-storage-test-'));
    const storage = new LocalVolumeStorage(tmpDir);
    await expect(storage.save('../escape.webp', Buffer.from('x'))).rejects.toThrow(/tidak valid/);
    await fs.rm(tmpDir, { recursive: true, force: true });
  });
});
