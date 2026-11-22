import { ConditionStatus, UserRole } from '@prisma/client';
import { describe, expect, it } from 'vitest';
import { assertCanWriteLocation } from '../../src/middlewares/rbac';
import { passwordPolicySchema } from '../../src/modules/auth/auth.schema';
import { createUserSchema } from '../../src/modules/master/master.schema';
import { sanitizeSpreadsheetCell } from '../../src/modules/reports/sanitizer';
import { updateConditionSchema } from '../../src/modules/stocks/stocks.schema';
import { extractEvidenceFilename } from '../../src/modules/uploads/local.storage';
import { detectAllowedImageMime } from '../../src/modules/uploads/magicBytes';

describe('Security & Domain Unit Tests (SRS v1.1)', () => {
  describe('Anti Excel Formula Injection (SRS-SEC-014)', () => {
    it('escapes cells starting with =, +, -, @, tab, or CR', () => {
      expect(sanitizeSpreadsheetCell('=CMD|\' /C calc\'!A0')).toBe("'=CMD|' /C calc'!A0");
      expect(sanitizeSpreadsheetCell('+1+1')).toBe("'+1+1");
      expect(sanitizeSpreadsheetCell('-2+3')).toBe("'-2+3");
      expect(sanitizeSpreadsheetCell('@SUM(A1:A5)')).toBe("'@SUM(A1:A5)");
      expect(sanitizeSpreadsheetCell('\t=1')).toBe("'\t=1");
      expect(sanitizeSpreadsheetCell('\r=1')).toBe("'\r=1");
    });

    it('keeps normal remarks untouched', () => {
      expect(sanitizeSpreadsheetCell('1 di job 1p-31-180')).toBe('1 di job 1p-31-180');
      expect(sanitizeSpreadsheetCell(null)).toBe('');
      expect(sanitizeSpreadsheetCell(undefined)).toBe('');
    });
  });

  describe('Magic-Byte Image Validation (SRS-SEC-008)', () => {
    it('accepts genuine JPEG, PNG, and WebP headers', () => {
      expect(detectAllowedImageMime(Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0, 0, 0, 0, 0]))).toBe('image/jpeg');
      expect(detectAllowedImageMime(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]))).toBe('image/png');
      expect(detectAllowedImageMime(Buffer.from('RIFF\x00\x00\x00\x00WEBPxxxx', 'binary'))).toBe('image/webp');
    });

    it('rejects PHP/EXE/HTML payloads disguised as images', () => {
      expect(detectAllowedImageMime(Buffer.from('<?php system($_GET["c"]); ?>'))).toBeNull();
      expect(detectAllowedImageMime(Buffer.from('MZ\x90\x00\x03\x00\x00\x00\x04\x00\x00\x00'))).toBeNull();
      expect(detectAllowedImageMime(Buffer.from('short'))).toBeNull();
    });
  });

  describe('Anti Path Traversal on Evidence Filename (SRS-SEC-008)', () => {
    it('extracts valid UUID webp filenames only', () => {
      expect(
        extractEvidenceFilename('/api/v1/uploads/evidence/123e4567-e89b-12d3-a456-426614174000.webp')
      ).toBe('123e4567-e89b-12d3-a456-426614174000.webp');
      expect(extractEvidenceFilename('/api/v1/uploads/evidence/../../etc/passwd')).toBeNull();
      expect(extractEvidenceFilename('http://evil.com/x.webp')).toBeNull();
    });
  });

  describe('Location RBAC — Read Global, Write Local (SRS-CAP-003)', () => {
    const base = { id: 1, username: 'u', fullName: 'U', mustChangePassword: false };

    it('allows SUPER_ADMIN on any location', () => {
      expect(() =>
        assertCanWriteLocation({ ...base, role: UserRole.SUPER_ADMIN, assignedLocationId: null }, 99)
      ).not.toThrow();
    });

    it('denies VIEWER on all write attempts', () => {
      expect(() =>
        assertCanWriteLocation({ ...base, role: UserRole.VIEWER, assignedLocationId: null }, 1)
      ).toThrow(/Viewer/);
    });

    it('allows ADMIN_GUDANG only on assigned warehouse', () => {
      const adminWh1 = { ...base, role: UserRole.ADMIN_GUDANG, assignedLocationId: 1 };
      expect(() => assertCanWriteLocation(adminWh1, 1, { allowFieldTech: false })).not.toThrow();
      expect(() => assertCanWriteLocation(adminWh1, 3, { allowFieldTech: false })).toThrow(/lokasi tugas/);
    });

    it('restricts PETUGAS_LAPANGAN from Stock In and other sites', () => {
      const techPts = { ...base, role: UserRole.PETUGAS_LAPANGAN, assignedLocationId: 3 };
      expect(() => assertCanWriteLocation(techPts, 3, { allowFieldTech: true })).not.toThrow();
      expect(() => assertCanWriteLocation(techPts, 3, { allowFieldTech: false })).toThrow(/Admin Gudang/);
      expect(() => assertCanWriteLocation(techPts, 1, { allowFieldTech: true })).toThrow(/lokasi tugas/);
    });
  });

  describe('Password Policy & User/Stock Schemas (SRS-SEC-002 & SRS-CAP-010)', () => {
    it('enforces >= 8 chars with uppercase, lowercase, and digit', () => {
      expect(passwordPolicySchema.safeParse('HtiSecure2026').success).toBe(true);
      expect(passwordPolicySchema.safeParse('weakpass').success).toBe(false);
      expect(passwordPolicySchema.safeParse('12345678').success).toBe(false);
      expect(passwordPolicySchema.safeParse('Ab1').success).toBe(false);
    });

    it('enforces role-to-location consistency on createUserSchema', () => {
      expect(
        createUserSchema.safeParse({
          username: 'viewer1',
          fullName: 'Pak Hanif',
          password: 'HtiSecure2026',
          role: UserRole.VIEWER,
          assignedLocationId: 1,
        }).success
      ).toBe(false);

      expect(
        createUserSchema.safeParse({
          username: 'tech1',
          fullName: 'Teknisi PTS',
          password: 'HtiSecure2026',
          role: UserRole.PETUGAS_LAPANGAN,
          assignedLocationId: null,
        }).success
      ).toBe(false);
    });

    it('rejects identical fromStatus and toStatus on condition update', () => {
      const res = updateConditionSchema.safeParse({
        itemId: 1,
        locationId: 1,
        fromStatus: ConditionStatus.GOOD,
        toStatus: ConditionStatus.GOOD,
        qty: 1,
        note: 'Test catatan valid',
        expectedVersion: 1,
      });
      expect(res.success).toBe(false);
    });
  });
});
