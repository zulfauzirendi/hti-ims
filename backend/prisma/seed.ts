import { PrismaClient, LocationType, UserRole } from '@prisma/client';
import argon2 from 'argon2';

const prisma = new PrismaClient();

const CATEGORIES = [
  { code: 'EQP', name: 'EQUIPMENT' },
  { code: 'TLS', name: 'TOOLS' },
  { code: 'ELP', name: 'ELECTRICAL & PNEUMATIC TOOLS' },
  { code: 'MSR', name: 'MEASURING TOOLS' },
  { code: 'HND', name: 'HAND TOOLS' },
  { code: 'LFT', name: 'LIFTING AND PULLING TOOLS' },
  { code: 'WHI', name: 'INVENTARIS WAREHOUSE' },
  { code: 'QCT', name: 'QUALITY CONTROL (QC) TOOLS' },
  { code: 'SFT', name: 'INVENTARIS SAFETY' },
] as const;

const LOCATIONS = [
  { code: 'WH-1', name: 'Warehouse 1', locationType: LocationType.WAREHOUSE },
  { code: 'WH-2', name: 'Warehouse 2', locationType: LocationType.WAREHOUSE },
  { code: 'SITE-PTS', name: 'Site PTS', locationType: LocationType.SITE },
  { code: 'SITE-NON-PTS', name: 'Site Non PTS', locationType: LocationType.SITE },
] as const;

async function main() {
  console.log('[SEED] Upserting 9 master categories...');
  for (const cat of CATEGORIES) {
    await prisma.category.upsert({
      where: { code: cat.code },
      update: { name: cat.name },
      create: cat,
    });
  }

  console.log('[SEED] Upserting 4 master locations...');
  const locMap = new Map<string, number>();
  for (const loc of LOCATIONS) {
    const saved = await prisma.location.upsert({
      where: { code: loc.code },
      update: { name: loc.name, locationType: loc.locationType, isActive: true },
      create: loc,
    });
    locMap.set(saved.code, saved.id);
  }

  // Initial bootstrap accounts — semua wajib ganti password saat login pertama (SRS-SEC-012)
  const bootstrapPassword = process.env.SEED_INITIAL_PASSWORD;
  if (!bootstrapPassword || bootstrapPassword.length < 12) {
    console.warn(
      '[SEED] SEED_INITIAL_PASSWORD tidak disetel (>= 12 karakter); melewati pembuatan akun awal demi keamanan produksi.'
    );
    return;
  }

  const passwordHash = await argon2.hash(bootstrapPassword, {
    type: argon2.argon2id,
    memoryCost: 65536, // 64 MiB (SRS-SEC-001)
    timeCost: 3,
    parallelism: 1,
  });

  const initialUsers = [
    { username: 'superadmin', fullName: 'Super Admin PT HTI', role: UserRole.SUPER_ADMIN, locCode: null },
    { username: 'admin_wh1', fullName: 'Admin Gudang Warehouse 1', role: UserRole.ADMIN_GUDANG, locCode: 'WH-1' },
    { username: 'admin_wh2', fullName: 'Admin Gudang Warehouse 2', role: UserRole.ADMIN_GUDANG, locCode: 'WH-2' },
    { username: 'site_pts', fullName: 'Petugas Lapangan Site PTS', role: UserRole.PETUGAS_LAPANGAN, locCode: 'SITE-PTS' },
    { username: 'site_nonpts', fullName: 'Petugas Lapangan Site Non PTS', role: UserRole.PETUGAS_LAPANGAN, locCode: 'SITE-NON-PTS' },
    { username: 'hanif', fullName: 'Pak Hanif (Management Viewer)', role: UserRole.VIEWER, locCode: null },
    { username: 'vika', fullName: 'Vika (Management Viewer)', role: UserRole.VIEWER, locCode: null },
  ];

  console.log('[SEED] Upserting initial RBAC user accounts (mustChangePassword = true)...');
  for (const u of initialUsers) {
    await prisma.user.upsert({
      where: { username: u.username },
      update: {},
      create: {
        username: u.username,
        passwordHash,
        fullName: u.fullName,
        role: u.role,
        assignedLocationId: u.locCode ? (locMap.get(u.locCode) ?? null) : null,
        mustChangePassword: true,
        isActive: true,
      },
    });
  }

  console.log('[SEED] Completed successfully.');
}

main()
  .catch((err) => {
    console.error('[SEED] Error:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
