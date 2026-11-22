# PT HTI Tool & Equipment Inventory System (HTI-TEIS)

Sistem manajemen inventaris peralatan dan perkakas kerja terpadu untuk **PT Hikari Teknologi Indonesia (PT HTI)** yang mendukung **Desktop (Windows/Linux)** dan **Android**, dirancang memenuhi standar kepatuhan **ISO 9001:2015** (*Quality Management & Immutable Audit Trail*) dan **ISO 45001:2018** (*K3 Equipment Reliability & Photographic Evidence*).

---

## Ringkasan Baseline Data (`Sheet: Nov 25`)
- **Total Item:** `531` jenis tool & equipment dalam `9` kategori utama (`EQP`, `TLS`, `ELP`, `MSR`, `HND`, `LFT`, `WHI`, `QCT`, `SFT`)
- **Total Volume:** `12.808` unit (`10.340` Good, `119` Service, `2.349` Broken)
- **4 Lokasi Operasional:** `Warehouse 1` (`WH-1`), `Warehouse 2` (`WH-2`), `Site PTS` (`SITE-PTS`), `Site Non PTS` (`SITE-NON-PTS`)
- **Kebijakan Otorisasi:** **Read Global, Write Local** (`SUPER_ADMIN`, `ADMIN_GUDANG`, `PETUGAS_LAPANGAN`, `VIEWER`) dengan alur mutasi antar lokasi **2 Tahap (`IN_TRANSIT` -> `RECEIVED` / `REJECTED` / `CANCELLED`)**.

---

## Struktur Proyek
```text
.
├── docs/                # Dokumen resmi SRS (MIL-STD-498 v1.1), HLD v1.0, LLD v1.0 (.md & .docx)
├── backend/             # REST API (Node.js 20, TypeScript, Express, Prisma ORM, PostgreSQL 16)
├── app/                 # Flutter Shared Codebase (Windows/Linux Desktop & Android SDK 26+)
├── migration/           # Python ETL Migrator & Automated Verifier untuk Excel 'Nov 25'
├── infra/               # Nginx TLS Reverse Proxy, Least-Privilege DB Roles, AES-256 Backup/Restore
├── docker-compose.yml   # Hybrid Docker Stack (Cloud VPS & On-Premise PT HTI)
└── .env.example         # Template konfigurasi environment (jangan commit .env!)
```

---

## Dokumentasi Rekayasa (`docs/`)
- **SRS (`HTI-SRS-TEIS-001 v1.1`):** `docs/SRS_PT_HTI_Tool_Equipment_Inventory_System.md` & `.docx`
- **HLD (`HTI-HLD-TEIS-001 v1.0`):** `docs/HLD_PT_HTI_Tool_Equipment_Inventory_System.md` & `.docx`
- **LLD (`HTI-LLD-TEIS-001 v1.0`):** `docs/LLD_PT_HTI_Tool_Equipment_Inventory_System.md` & `.docx`

---

## Quickstart Backend & Database (Development)
```bash
# 1. Salin environment template & isi secret acak (>= 32 karakter)
cp .env.example .env

# 2. Hidupkan PostgreSQL 16 (port 5432 hanya terikat ke 127.0.0.1)
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d postgres

# 3. Install dependensi, generate Prisma Client & jalankan migrasi skema
cd backend
npm install
npx prisma generate
npx prisma migrate deploy

# 4. Terapkan peran least-privilege (REVOKE UPDATE/DELETE pada stock_logs)
psql "$DIRECT_DATABASE_URL" -f ../infra/scripts/apply_db_grants.sql

# 5. Seed kategori, lokasi & akun awal (wajib ganti password saat login pertama)
SEED_INITIAL_PASSWORD="GantiPasswordKuat2026!" npm run prisma:seed

# 6. Jalankan migrasi & rekonsiliasi 100% data baseline Excel Nov 25
python3 ../migration/migrate_nov25.py --dry-run
python3 ../migration/migrate_nov25.py

# 7. Jalankan API & Unit Tests
npm test
npm run dev
```

---

## Quickstart Flutter Client (Desktop Linux/Windows & Android)
```bash
cd app

# Analisis statis & jalankan seluruh unit/widget tests
flutter analyze
flutter test

# Jalankan di Linux Desktop (mode dev)
flutter run -d linux

# Jalankan di perangkat Android tersambung (ADB)
flutter run -d android

# Build rilis Android ter-obfuscate (SRS-SEC-011)
flutter build apk --release --obfuscate --split-debug-info=build/symbols

# Build rilis Linux Desktop
flutter build linux --release
```
