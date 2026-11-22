# LOW-LEVEL DESIGN (LLD)
## PT HTI TOOL & EQUIPMENT INVENTORY SYSTEM (HTI-TEIS)

---

| Atribut Dokumen | Keterangan |
| :--- | :--- |
| **Document Identifier** | `HTI-LLD-TEIS-001` |
| **Standard Reference** | MIL-STD-498 (Software Design Description — Detailed Design) & ISO/IEC/IEEE 1016 |
| **Parent Documents** | `HTI-SRS-TEIS-001` (`v1.1`) & `HTI-HLD-TEIS-001` (`v1.0`) |
| **Version** | `1.0` (Implementation-Ready Detailed Design) |
| **Date** | 22 November 2026 |
| **Classification** | INTERNAL CONFIDENTIAL — PT HIKARI TEKNOLOGI INDONESIA |
| **Prepared For** | Tim Backend, Flutter (Desktop/Android), QA & DevOps — **PT Hikari Teknologi Indonesia (PT HTI)** |
| **Prepared By** | Systems Architecture & Software Engineering Team |

---

## LEMBAR PENGESAHAN (APPROVAL SHEET)

| Peran | Nama / Jabatan | Tanda Tangan | Tanggal |
| :--- | :--- | :--- | :--- |
| **Approved (Lead Engineer)** | Principal Backend & Mobile Architect | __________________________ | ____ / ____ / 2026 |
| **Accepted (Project Manager)** | Software Project Manager | __________________________ | ____ / ____ / 2026 |
| **Reviewed (QA & Security)** | QA Automation & Security Lead | __________________________ | ____ / ____ / 2026 |

---

## RECORD OF CHANGES

| Version | Date | Section | Change Type (`A`/`M`/`D`) | Description | Author |
| :---: | :---: | :--- | :---: | :--- | :--- |
| `1.0` | 22 Nov 2026 | Seluruh Dokumen (`1`–`8`) | `A` | Penyusunan awal dokumen *Low-Level Design* (LLD) siap implementasi: skema fisik PostgreSQL/Prisma, kontrak JSON/Zod REST API, algoritma & *state machine* backend, arsitektur state/widget Flutter, desain ETL migrasi Python `Nov 25`, konfigurasi Docker/Nginx/Backup, dan rencana pengujian tingkat unit/integrasi/beban. | Systems Architecture Team |

---

## TABLE OF CONTENTS

1. **PROJECT STRUCTURE, CONVENTIONS & ERROR REGISTRY**
   - 1.1 Monorepo Directory Blueprint
   - 1.2 Coding Standards & Naming Conventions
   - 1.3 Standardized Machine Error Code Registry
2. **DETAILED DATABASE DESIGN (PHYSICAL SCHEMA & PRISMA)**
   - 2.1 Physical Data Dictionary (8 Tables)
   - 2.2 Complete `prisma/schema.prisma` Blueprint
   - 2.3 Post-Migration Custom SQL (Extensions, Checks, Indexes & DB Privileges)
   - 2.4 High-Performance Query Patterns (`< 300 ms p95`)
3. **DETAILED REST API CONTRACT & ZOD VALIDATION SCHEMAS**
   - 3.1 Common Headers, Pagination & Envelope Specification
   - 3.2 Auth & Account Lifecycle Endpoints
   - 3.3 Dashboard, Items & Instant Search Endpoints
   - 3.4 Stock Mutation & Evidence Upload Endpoints
   - 3.5 Two-Stage Transfer Endpoints
   - 3.6 Audit Logs, Compliance Export & Master/User Endpoints
4. **BACKEND MODULE ALGORITHMS & STATE MACHINES**
   - 4.1 Auth, `must_change_password` Gate & Refresh Token Reuse Detection
   - 4.2 Location RBAC Authorization Guard (`Read Global, Write Local`)
   - 4.3 Atomic Stock Condition Update & Optimistic Locking (`version`)
   - 4.4 Two-Stage Transfer State Machine & Atomic Transitions
   - 4.5 Secure Evidence Upload Pipeline (`Magic Bytes` + `Sharp` EXIF Strip + `StorageService`)
   - 4.6 Safe Excel & PDF Report Generator (Anti Formula Injection)
   - 4.7 Structured Logging (`Pino`), Redaction & Global Error Handler
5. **FLUTTER CLIENT LOW-LEVEL DESIGN (DESKTOP & ANDROID)**
   - 5.1 Flutter Source Tree (`lib/`)
   - 5.2 Single-Flight `Dio` Auth Refresh Interceptor & Degraded Connectivity Handling
   - 5.3 Riverpod State Providers & Debounced Search Design
   - 5.4 `GoRouter` Route Table & Security/Role Guards
   - 5.5 Component & Screen Blueprints (`DesktopShell` vs `MobileShell`)
6. **PYTHON BASELINE EXCEL MIGRATION DESIGN (`HTI-TEIS-MIG-01`)**
   - 6.1 ETL Pipeline Stages & Normalization Rules
   - 6.2 Deterministic SKU Generator & `job_code` Regex Parser
   - 6.3 Automated Reconciliation Assertion Gate (`531` Items / `12.808` Units)
7. **INFRASTRUCTURE, DOCKER & ENCRYPTED BACKUP BLUEPRINTS**
   - 7.1 Hardened Multi-Stage `Dockerfile` (`USER node`)
   - 7.2 Isolated `docker-compose.yml` Network & Volume Specification
   - 7.3 Nginx TLS Reverse Proxy Blueprint
   - 7.4 Automated `AES-256` Encrypted Backup & Restore Algorithms
8. **LOW-LEVEL TESTING STRATEGY & TEST CASE MATRIX**

---

# 1. PROJECT STRUCTURE, CONVENTIONS & ERROR REGISTRY

## 1.1 Monorepo Directory Blueprint

```text
PT HTI Tool & Equipment Inventory System/
├── backend/
│   ├── prisma/
│   │   ├── schema.prisma
│   │   ├── migrations/
│   │   │   └── 0001_init_hti_teis/migration.sql   # Includes pg_trgm, CHECK, GIN indexes
│   │   └── seed.ts                                # Categories, 4 Locations, initial Super Admin
│   ├── src/
│   │   ├── config/
│   │   │   ├── env.ts                             # Zod fail-fast .env parser
│   │   │   ├── logger.ts                          # Pino JSON logger + secret redaction
│   │   │   └── prisma.ts                          # PrismaClient singleton
│   │   ├── middlewares/
│   │   │   ├── requestId.ts                       # X-Request-Id propagation
│   │   │   ├── authenticate.ts                    # JWT verify + user is_active check
│   │   │   ├── requirePasswordChanged.ts          # Blocks ops if must_change_password=true
│   │   │   ├── rbac.ts                            # authorizeRoles & authorizeLocationWrite
│   │   │   ├── rateLimiter.ts                     # 10/15m login & 120/m general
│   │   │   ├── validate.ts                        # Zod body/query/params validator
│   │   │   └── errorHandler.ts                    # AppError / Zod / Prisma -> HTTP Envelope
│   │   ├── modules/
│   │   │   ├── health/        (routes, controller)
│   │   │   ├── auth/          (routes, controller, service, schema)
│   │   │   ├── dashboard/     (routes, controller, service)
│   │   │   ├── items/         (routes, controller, service, schema)
│   │   │   ├── stocks/        (routes, controller, service, schema)
│   │   │   ├── transfers/     (routes, controller, service, schema)
│   │   │   ├── uploads/       (routes, controller, service, storage.interface, local.storage)
│   │   │   ├── logs/          (routes, controller, service, schema)
│   │   │   ├── reports/       (routes, controller, service, excel.builder, pdf.builder, sanitizer)
│   │   │   └── master/        (categories, locations, users: routes, controller, service, schema)
│   │   ├── utils/
│   │   │   ├── appError.ts
│   │   │   ├── crypto.ts                          # Argon2id / SHA-256 / UUID helpers
│   │   │   └── idempotency.ts                     # Optional X-Idempotency-Key cache
│   │   ├── app.ts
│   │   └── server.ts                              # Graceful SIGTERM/SIGINT shutdown
│   ├── tests/
│   │   ├── unit/
│   │   ├── integration/
│   │   └── load/k6_search_mutation.js
│   ├── Dockerfile
│   ├── package.json
│   └── tsconfig.json
├── app/                                           # Flutter Shared App (Windows/Linux/Android)
│   ├── lib/
│   │   ├── core/
│   │   ├── features/
│   │   ├── layouts/
│   │   └── main.dart
│   ├── test/
│   └── pubspec.yaml
├── migration/
│   ├── migrate_nov25.py
│   ├── verify_baseline.py
│   └── requirements.txt
├── infra/
│   ├── nginx/nginx.conf
│   └── scripts/ (backup.sh, restore.sh, init_db_roles.sql)
├── docs/
│   ├── SRS_PT_HTI_Tool_Equipment_Inventory_System.md (.docx)
│   ├── HLD_PT_HTI_Tool_Equipment_Inventory_System.md (.docx)
│   └── LLD_PT_HTI_Tool_Equipment_Inventory_System.md (.docx)
├── docker-compose.yml
├── docker-compose.staging.yml
├── .env.example
└── .gitignore
```

## 1.2 Coding Standards & Naming Conventions

* **TypeScript (`backend/`):** `strict: true`, `noUncheckedIndexedAccess: true`, `noImplicitReturns: true`. Penamaan berkas `camelCase.ts` (atau `kebab-case.ts`), kelas/tipe `PascalCase`, konstanta `UPPER_SNAKE_CASE`, kolom DB `snake_case` (dipetakan via Prisma `@map` ke properti `camelCase` di TS/JSON).
* **Dart/Flutter (`app/`):** Mengikuti `flutter_lints` + `Effective Dart`. Berkas `snake_case.dart`, kelas/widget `PascalCase`, state model *immutable* (`freezed` atau `equatable` + `copyWith`).
* **Git & Rahasia:** `.env`, `*.jks`, `key.properties`, `*.pem`, `*.key`, dan `/storage/evidence/*` wajib masuk `.gitignore`.

## 1.3 Standardized Machine Error Code Registry

| HTTP | `error.code` | Penyebab | Tindakan Klien |
| :---: | :--- | :--- | :--- |
| `400` | `SAFETY_PHOTO_REQUIRED` | Transisi ke `SERVICE`/`BROKEN` tanpa `photoUrl` atau `note` (`< 5` karakter) | Tampilkan pesan wajib ambil/unggah foto bukti K3 |
| `400` | `INSUFFICIENT_STOCK` | Saldo sumber `< qty` yang diminta | Tampilkan saldo aktual & minta kurangi `qty` |
| `400` | `TRANSFER_SAME_LOCATION` | `fromLocationId === toLocationId` | Minta pilih lokasi tujuan yang berbeda |
| `400` | `TRANSFER_INVALID_STATE` | Aksi terima/tolak/batal pada transfer bukan `IN_TRANSIT` | Muat ulang daftar transfer |
| `400` | `ITEM_HAS_ACTIVE_STOCK` | Mencoba *soft delete* item yang masih memiliki saldo `> 0` atau `IN_TRANSIT` | Tampilkan peringatan nolkan/selesaikan stok dulu |
| `401` | `AUTH_INVALID_CREDENTIALS` | Username/password salah | Tampilkan pesan generik (jangan sebut mana yang salah) |
| `401` | `AUTH_TOKEN_EXPIRED` | Access Token kedaluwarsa | Interceptor otomatis memanggil `/auth/refresh` |
| `401` | `AUTH_TOKEN_REUSE_DETECTED` | Refresh token lama terpakai ulang (indikasi pencurian) | Bersihkan storage lokal & paksa login ulang |
| `403` | `AUTH_ACCOUNT_INACTIVE` | Akun dinonaktifkan (`is_active = FALSE`) | Logout otomatis & arahkan ke Login |
| `403` | `AUTH_MUST_CHANGE_PASSWORD` | Akses endpoint operasional saat `must_change_password = TRUE` | Arahkan paksa ke layar `/change-password` |
| `403` | `RBAC_ROLE_DENIED` | Peran tidak berhak mengakses endpoint (`VIEWER` mencoba mutasi) | Tampilkan pesan akses ditolak |
| `403` | `RBAC_LOCATION_DENIED` | Mencoba tulis di luar `assigned_location_id` | Tampilkan pesan batas lokasi tugas |
| `404` | `RESOURCE_NOT_FOUND` | Item / Transfer / File bukti tidak ditemukan | Tampilkan pesan data tidak tersedia |
| `409` | `STOCK_VERSION_CONFLICT` | *Optimistic locking* gagal (data telah diubah pengguna lain) | Tampilkan banner konflik & tombol muat ulang data terbaru |
| `409` | `DUPLICATE_RESOURCE` | Username / SKU / Kode lokasi sudah terdaftar | Minta ubah nilai unik |
| `413` | `UPLOAD_FILE_TOO_LARGE` | Berkas foto `> 2 MB` | Minta kompres ulang atau pilih foto lain |
| `415` | `UPLOAD_INVALID_MAGIC_BYTES` | *Magic bytes* bukan JPEG/PNG/WebP | Tolak berkas & tampilkan format gambar yang diizinkan |
| `422` | `VALIDATION_ERROR` | Payload tidak lolos skema Zod (`error.details` memuat field error) | Tandai field formulir terkait secara *inline* |
| `429` | `RATE_LIMIT_EXCEEDED` | Melebihi kuota permintaan (`10/15m` login atau `120/m` API) | Tampilkan hitung mundur jeda coba lagi |
| `503` | `SERVICE_MAINTENANCE` | Sistem sedang dalam mode pemeliharaan terencana | Tampilkan layar pemeliharaan + `Retry-After` |

---

# 2. DETAILED DATABASE DESIGN (PHYSICAL SCHEMA & PRISMA)

## 2.1 Physical Data Dictionary (8 Tables)

| Tabel | Kolom Kunci & Tipe Fisik | Constraint / Aturan Penting |
| :--- | :--- | :--- |
| **`categories`** | `id SERIAL PK`, `code VARCHAR(10) UQ NOT NULL`, `name VARCHAR(100) UQ NOT NULL`, `created_at TIMESTAMPTZ` | 9 kode baku (`EQP`, `TLS`, `ELP`, `MSR`, `HND`, `LFT`, `WHI`, `QCT`, `SFT`). |
| **`locations`** | `id SERIAL PK`, `code VARCHAR(20) UQ NOT NULL`, `name VARCHAR(100) UQ NOT NULL`, `location_type VARCHAR(20) NOT NULL`, `is_active BOOLEAN DEFAULT TRUE`, `created_at TIMESTAMPTZ` | `location_type IN ('WAREHOUSE','SITE')`. 4 kode awal: `WH-1`, `WH-2`, `SITE-PTS`, `SITE-NON-PTS`. |
| **`items`** | `id SERIAL PK`, `item_code VARCHAR(30) UQ NOT NULL`, `category_id INT FK NOT NULL`, `description VARCHAR(255) NOT NULL`, `specification TEXT`, `unit VARCHAR(20) NOT NULL`, `is_active BOOLEAN DEFAULT TRUE`, `deleted_at TIMESTAMPTZ NULL`, `created_at TIMESTAMPTZ`, `updated_at TIMESTAMPTZ` | `ON DELETE RESTRICT` ke `categories`. `item_code` format `HTI-<CAT>-<SEQ>`. Indeks GIN `pg_trgm` pada `description` & `specification`. |
| **`users`** | `id SERIAL PK`, `username VARCHAR(50) UQ NOT NULL`, `password_hash VARCHAR(255) NOT NULL`, `full_name VARCHAR(100) NOT NULL`, `role VARCHAR(30) NOT NULL`, `assigned_location_id INT FK NULL`, `must_change_password BOOLEAN DEFAULT TRUE`, `is_active BOOLEAN DEFAULT TRUE`, `created_at TIMESTAMPTZ`, `updated_at TIMESTAMPTZ` | `role IN ('SUPER_ADMIN','ADMIN_GUDANG','PETUGAS_LAPANGAN','VIEWER')`. `assigned_location_id` `NULL` untuk `SUPER_ADMIN` & `VIEWER`, wajib terisi untuk `ADMIN_GUDANG` & `PETUGAS_LAPANGAN`. |
| **`refresh_tokens`** | `id SERIAL PK`, `user_id INT FK NOT NULL`, `family_id UUID NOT NULL`, `token_hash VARCHAR(64) UQ NOT NULL`, `device_info VARCHAR(150)`, `expires_at TIMESTAMPTZ NOT NULL`, `revoked_at TIMESTAMPTZ NULL`, `created_at TIMESTAMPTZ` | `ON DELETE CASCADE` dari `users`. `token_hash` = hex SHA-256. `family_id` digunakan untuk mencabut rantai token saat *reuse detection*. |
| **`item_stocks`** | `id SERIAL PK`, `item_id INT FK NOT NULL`, `location_id INT FK NOT NULL`, `qty_good INT DEFAULT 0`, `qty_service INT DEFAULT 0`, `qty_broken INT DEFAULT 0`, `qty_in_transit INT DEFAULT 0`, `job_code VARCHAR(100)`, `remarks TEXT`, `version INT DEFAULT 1`, `updated_by INT FK NULL`, `updated_at TIMESTAMPTZ` | `UNIQUE (item_id, location_id)`. `CHECK (qty_good >= 0 AND qty_service >= 0 AND qty_broken >= 0 AND qty_in_transit >= 0)`. `version` dinaikkan `+1` setiap update. |
| **`stock_transfers`** | `id SERIAL PK`, `transfer_code VARCHAR(40) UQ NOT NULL`, `item_id INT FK NOT NULL`, `from_location_id INT FK NOT NULL`, `to_location_id INT FK NOT NULL`, `condition_status VARCHAR(20) NOT NULL`, `qty INT NOT NULL`, `status VARCHAR(20) DEFAULT 'IN_TRANSIT'`, `job_code VARCHAR(100)`, `sender_note TEXT`, `receiver_note TEXT`, `sent_by INT FK NOT NULL`, `received_by INT FK NULL`, `sent_at TIMESTAMPTZ`, `resolved_at TIMESTAMPTZ NULL` | `CHECK (qty > 0)`, `CHECK (from_location_id <> to_location_id)`. `status IN ('IN_TRANSIT','RECEIVED','REJECTED','CANCELLED')`. `condition_status IN ('GOOD','SERVICE','BROKEN')`. |
| **`stock_logs`** | `id SERIAL PK`, `item_id INT FK NOT NULL`, `from_location_id INT FK NULL`, `to_location_id INT FK NULL`, `action_type VARCHAR(30) NOT NULL`, `status_changed VARCHAR(40) NULL`, `qty_changed INT NOT NULL`, `qty_before JSONB NULL`, `qty_after JSONB NULL`, `job_code VARCHAR(100)`, `note TEXT`, `photo_url VARCHAR(500)`, `transfer_id INT FK NULL`, `user_id INT FK NULL`, `created_at TIMESTAMPTZ` | **APPEND-ONLY** (hak `UPDATE`/`DELETE` dicabut di level DB role aplikasi). `ON DELETE RESTRICT` pada `item_id`, `from_location_id`, `to_location_id`. |

## 2.2 Complete `prisma/schema.prisma` Blueprint

```prisma
generator client {
  provider        = "prisma-client-js"
  previewFeatures = ["postgresqlExtensions"]
}

datasource db {
  provider   = "postgresql"
  url        = env("DATABASE_URL")
  extensions = [pg_trgm]
}

enum LocationType {
  WAREHOUSE
  SITE
}

enum UserRole {
  SUPER_ADMIN
  ADMIN_GUDANG
  PETUGAS_LAPANGAN
  VIEWER
}

enum ConditionStatus {
  GOOD
  SERVICE
  BROKEN
}

enum TransferStatus {
  IN_TRANSIT
  RECEIVED
  REJECTED
  CANCELLED
}

enum StockActionType {
  INITIAL_IMPORT
  STATUS_CHANGE
  STOCK_IN
  DISPOSAL
  TRANSFER_OUT
  TRANSFER_IN
  TRANSFER_REJECT
  TRANSFER_CANCEL
  REMARKS_UPDATE
}

model Category {
  id        Int      @id @default(autoincrement())
  code      String   @unique @db.VarChar(10)
  name      String   @unique @db.VarChar(100)
  createdAt DateTime @default(now()) @map("created_at") @db.Timestamptz(6)
  items     Item[]

  @@map("categories")
}

model Location {
  id                Int             @id @default(autoincrement())
  code              String          @unique @db.VarChar(20)
  name              String          @unique @db.VarChar(100)
  locationType      LocationType    @default(WAREHOUSE) @map("location_type")
  isActive          Boolean         @default(true) @map("is_active")
  createdAt         DateTime        @default(now()) @map("created_at") @db.Timestamptz(6)
  users             User[]
  stocks            ItemStock[]
  outgoingTransfers StockTransfer[] @relation("TransferFrom")
  incomingTransfers StockTransfer[] @relation("TransferTo")
  logsFrom          StockLog[]      @relation("LogFromLocation")
  logsTo            StockLog[]      @relation("LogToLocation")

  @@map("locations")
}

model Item {
  id            Int             @id @default(autoincrement())
  itemCode      String          @unique @map("item_code") @db.VarChar(30)
  categoryId    Int             @map("category_id")
  description   String          @db.VarChar(255)
  specification String?         @db.Text
  unit          String          @db.VarChar(20)
  isActive      Boolean         @default(true) @map("is_active")
  deletedAt     DateTime?       @map("deleted_at") @db.Timestamptz(6)
  createdAt     DateTime        @default(now()) @map("created_at") @db.Timestamptz(6)
  updatedAt     DateTime        @updatedAt @map("updated_at") @db.Timestamptz(6)

  category  Category        @relation(fields: [categoryId], references: [id], onDelete: Restrict)
  stocks    ItemStock[]
  transfers StockTransfer[]
  logs      StockLog[]

  @@index([categoryId], map: "idx_items_category")
  @@map("items")
}

model User {
  id                 Int             @id @default(autoincrement())
  username           String          @unique @db.VarChar(50)
  passwordHash       String          @map("password_hash") @db.VarChar(255)
  fullName           String          @map("full_name") @db.VarChar(100)
  role               UserRole
  assignedLocationId Int?            @map("assigned_location_id")
  mustChangePassword Boolean         @default(true) @map("must_change_password")
  isActive           Boolean         @default(true) @map("is_active")
  createdAt          DateTime        @default(now()) @map("created_at") @db.Timestamptz(6)
  updatedAt          DateTime        @updatedAt @map("updated_at") @db.Timestamptz(6)

  assignedLocation  Location?       @relation(fields: [assignedLocationId], references: [id], onDelete: SetNull)
  refreshTokens     RefreshToken[]
  updatedStocks     ItemStock[]
  sentTransfers     StockTransfer[] @relation("TransferSender")
  receivedTransfers StockTransfer[] @relation("TransferReceiver")
  stockLogs         StockLog[]

  @@map("users")
}

model RefreshToken {
  id         Int       @id @default(autoincrement())
  userId     Int       @map("user_id")
  familyId   String    @map("family_id") @db.Uuid
  tokenHash  String    @unique @map("token_hash") @db.VarChar(64)
  deviceInfo String?   @map("device_info") @db.VarChar(150)
  expiresAt  DateTime  @map("expires_at") @db.Timestamptz(6)
  revokedAt  DateTime? @map("revoked_at") @db.Timestamptz(6)
  createdAt  DateTime  @default(now()) @map("created_at") @db.Timestamptz(6)

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId, familyId], map: "idx_refresh_tokens_user_family")
  @@map("refresh_tokens")
}

model ItemStock {
  id           Int      @id @default(autoincrement())
  itemId       Int      @map("item_id")
  locationId   Int      @map("location_id")
  qtyGood      Int      @default(0) @map("qty_good")
  qtyService   Int      @default(0) @map("qty_service")
  qtyBroken    Int      @default(0) @map("qty_broken")
  qtyInTransit Int      @default(0) @map("qty_in_transit")
  jobCode      String?  @map("job_code") @db.VarChar(100)
  remarks      String?  @db.Text
  version      Int      @default(1)
  updatedById  Int?     @map("updated_by")
  updatedAt    DateTime @updatedAt @map("updated_at") @db.Timestamptz(6)

  item      Item     @relation(fields: [itemId], references: [id], onDelete: Restrict)
  location  Location @relation(fields: [locationId], references: [id], onDelete: Restrict)
  updatedBy User?    @relation(fields: [updatedById], references: [id], onDelete: SetNull)

  @@unique([itemId, locationId], map: "unique_item_location")
  @@index([locationId], map: "idx_item_stocks_location")
  @@map("item_stocks")
}

model StockTransfer {
  id              Int             @id @default(autoincrement())
  transferCode    String          @unique @map("transfer_code") @db.VarChar(40)
  itemId          Int             @map("item_id")
  fromLocationId  Int             @map("from_location_id")
  toLocationId    Int             @map("to_location_id")
  conditionStatus ConditionStatus @default(GOOD) @map("condition_status")
  qty             Int
  status          TransferStatus  @default(IN_TRANSIT)
  jobCode         String?         @map("job_code") @db.VarChar(100)
  senderNote      String?         @map("sender_note") @db.Text
  receiverNote    String?         @map("receiver_note") @db.Text
  sentById        Int             @map("sent_by")
  receivedById    Int?            @map("received_by")
  sentAt          DateTime        @default(now()) @map("sent_at") @db.Timestamptz(6)
  resolvedAt      DateTime?       @map("resolved_at") @db.Timestamptz(6)

  item         Item       @relation(fields: [itemId], references: [id], onDelete: Restrict)
  fromLocation Location   @relation("TransferFrom", fields: [fromLocationId], references: [id], onDelete: Restrict)
  toLocation   Location   @relation("TransferTo", fields: [toLocationId], references: [id], onDelete: Restrict)
  sentBy       User       @relation("TransferSender", fields: [sentById], references: [id], onDelete: Restrict)
  receivedBy   User?      @relation("TransferReceiver", fields: [receivedById], references: [id], onDelete: SetNull)
  logs         StockLog[]

  @@index([toLocationId, status], map: "idx_stock_transfers_incoming")
  @@index([fromLocationId, status], map: "idx_stock_transfers_outgoing")
  @@map("stock_transfers")
}

model StockLog {
  id             Int             @id @default(autoincrement())
  itemId         Int             @map("item_id")
  fromLocationId Int?            @map("from_location_id")
  toLocationId   Int?            @map("to_location_id")
  actionType     StockActionType @map("action_type")
  statusChanged  String?         @map("status_changed") @db.VarChar(40)
  qtyChanged     Int             @map("qty_changed")
  qtyBefore      Json?           @map("qty_before") @db.JsonB
  qtyAfter       Json?           @map("qty_after") @db.JsonB
  jobCode        String?         @map("job_code") @db.VarChar(100)
  note           String?         @db.Text
  photoUrl       String?         @map("photo_url") @db.VarChar(500)
  transferId     Int?            @map("transfer_id")
  userId         Int?            @map("user_id")
  createdAt      DateTime        @default(now()) @map("created_at") @db.Timestamptz(6)

  item         Item           @relation(fields: [itemId], references: [id], onDelete: Restrict)
  fromLocation Location?      @relation("LogFromLocation", fields: [fromLocationId], references: [id], onDelete: Restrict)
  toLocation   Location?      @relation("LogToLocation", fields: [toLocationId], references: [id], onDelete: Restrict)
  transfer     StockTransfer? @relation(fields: [transferId], references: [id], onDelete: SetNull)
  user         User?          @relation(fields: [userId], references: [id], onDelete: SetNull)

  @@index([createdAt(sort: Desc)], map: "idx_stock_logs_created_desc")
  @@index([itemId, createdAt(sort: Desc)], map: "idx_stock_logs_item_created")
  @@map("stock_logs")
}
```

## 2.3 Post-Migration Custom SQL (Extensions, Checks, Indexes & DB Privileges)

Disertakan langsung pada migrasi SQL Prisma pertama (`0001_init_hti_teis/migration.sql`) dan skrip inisialisasi peran DB (`infra/scripts/init_db_roles.sql`):

```sql
-- 1. Trigram Search Extension & GIN Indexes (< 50 ms DB search)
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_items_description_trgm ON items USING GIN (description gin_trgm_ops);
CREATE INDEX idx_items_spec_trgm ON items USING GIN (specification gin_trgm_ops);
CREATE INDEX idx_items_code_trgm ON items USING GIN (item_code gin_trgm_ops);
CREATE INDEX idx_items_active_category ON items (category_id) WHERE is_active = TRUE;

-- 2. Strict Domain Integrity Check Constraints
ALTER TABLE item_stocks
  ADD CONSTRAINT chk_stocks_non_negative
  CHECK (qty_good >= 0 AND qty_service >= 0 AND qty_broken >= 0 AND qty_in_transit >= 0);

ALTER TABLE stock_transfers
  ADD CONSTRAINT chk_transfer_qty_positive CHECK (qty > 0),
  ADD CONSTRAINT chk_transfer_diff_locations CHECK (from_location_id <> to_location_id);

-- 3. Least-Privilege Application Role & Immutable Audit Table (SRS-SEC-013 & SRS-SAF-006)
-- Peran migrasi ('hti_migrator') menjalankan DDL; peran runtime API ('hti_app') terbatas:
GRANT SELECT, INSERT, UPDATE, DELETE ON categories, locations, items, users, refresh_tokens, item_stocks, stock_transfers TO hti_app;
GRANT SELECT, INSERT ON stock_logs TO hti_app;
REVOKE UPDATE, DELETE, TRUNCATE ON stock_logs FROM hti_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO hti_app;
```

## 2.4 High-Performance Query Patterns (`< 300 ms p95`)

Untuk `GET /api/v1/items/search`:
1. **Query 1 (Matched Item IDs + Total Count):** Menggunakan indeks GIN `pg_trgm` (`description ILIKE '%q%' OR specification ILIKE '%q%' OR item_code ILIKE '%q%'`) dengan `WHERE is_active = TRUE`, filter opsional `category_id`, serta `EXISTS (SELECT 1 FROM item_stocks s WHERE s.item_id = i.id AND ...)` bila filter `location_id`/`condition` aktif. Mengembalikan maks `limit` (default `20`) ID item + `COUNT(*) OVER()`.
2. **Query 2 (Hydrate 4-Location Matrix):** Mengambil 20 item lengkap dengan relasi `category` dan seluruh `item_stocks` + `location` (`WHERE item_id IN (...)`). Total hanya **2 query terindeks** — meniadakan masalah *N+1 query* dan menjaga latensi `p95 <= 150 ms` di sisi server.

---

# 3. DETAILED REST API CONTRACT & ZOD VALIDATION SCHEMAS

## 3.1 Common Headers, Pagination & Envelope Specification

* **Request Headers:**
  * `Authorization: Bearer <accessToken>` (wajib untuk semua endpoint selain `/health`, `/auth/login`, `/auth/refresh`)
  * `X-Request-Id: <uuid>` (opsional dari klien; bila kosong dibuat otomatis oleh backend dan dikembalikan di respons)
  * `X-Idempotency-Key: <uuid>` (wajib pada mutasi stok & transfer dari klien Flutter guna mencegah duplikasi *double-tap* / retry jaringan)
* **Standard Response Envelope:**
```json
{
  "success": true,
  "data": { },
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 531,
    "totalPages": 27,
    "requestId": "c2a8f491-3f2b-41ef-a892-19e7a104bc11"
  }
}
```

## 3.2 Auth & Account Lifecycle Endpoints

| Endpoint | Request Body (Zod Rules) | Response `200 OK` (`data`) |
| :--- | :--- | :--- |
| `POST /api/v1/auth/login` | `{ username: str(3..50), password: str(1..128), deviceInfo?: str(<=150) }` | `{ accessToken, refreshToken, expiresIn: 900, user: { id, username, fullName, role, mustChangePassword, assignedLocation } }` |
| `POST /api/v1/auth/refresh` | `{ refreshToken: str(min 32) }` | `{ accessToken, refreshToken, expiresIn: 900 }` |
| `POST /api/v1/auth/logout` | `{ refreshToken: str(min 32) }` | `{ revoked: true }` |
| `POST /api/v1/auth/change-password` | `{ currentPassword: str, newPassword: str(min 8, regex upper+lower+digit) }` | `{ passwordUpdated: true, mustChangePassword: false }` |
| `GET /api/v1/auth/me` | — | `{ id, username, fullName, role, mustChangePassword, assignedLocation }` |

## 3.3 Dashboard, Items & Instant Search Endpoints

* **`GET /api/v1/health`** *(Public)*:
  `{ status: "ok", db: "up", storage: "up", serverTimeUtc: "...", minClientVersion: "1.0.0", latestClientVersion: "1.0.0" }`
* **`GET /api/v1/dashboard/summary`**:
  ```json
  {
    "grandTotal": { "itemsCount": 531, "good": 10340, "service": 119, "broken": 2349, "inTransit": 0, "totalVolume": 12808 },
    "byLocation": [
      { "locationId": 1, "code": "WH-1", "name": "Warehouse 1", "good": 8096, "service": 111, "broken": 2242, "inTransit": 0, "total": 10449 }
    ],
    "byCategory": [
      { "categoryId": 1, "code": "EQP", "name": "EQUIPMENT", "totalItems": 42, "totalUnits": 310 }
    ],
    "pendingIncomingTransfers": 3
  }
  ```
* **`GET /api/v1/items/search`**:
  * Query params (Zod): `q?: str(<=100)`, `categoryId?: int`, `locationId?: int`, `condition?: 'GOOD'|'SERVICE'|'BROKEN'|'IN_TRANSIT'`, `page?: int(>=1, default 1)`, `limit?: int(1..100, default 20)`.
  * Item response menyertakan `stocks: [{ locationId, locationCode, locationName, qtyGood, qtyService, qtyBroken, qtyInTransit, jobCode, remarks, version, updatedAt }]`.
* **`POST /api/v1/items`** (`SUPER_ADMIN`): `{ categoryId: int, description: str(2..255), specification?: str(<=2000), unit: enum('UNIT','PCS','SET','ROLL','EA','PAIR','BOX','BTL') }` $\rightarrow$ `201` dengan `itemCode` ter-generate otomatis.
* **`DELETE /api/v1/items/:id`** (`SUPER_ADMIN`): Menjalankan *soft delete* (`isActive = false, deletedAt = now()`) setelah memverifikasi total seluruh `qty_* == 0` dan tidak ada transfer `IN_TRANSIT`.

## 3.4 Stock Mutation & Evidence Upload Endpoints

* **`POST /api/v1/uploads/evidence`** *(Multipart `file`)*:
  * Field form: `file` (maks `2 MB`, magic bytes `image/jpeg|png|webp`).
  * Respons `201`: `{ filename: "<uuid>.webp", photoUrl: "/api/v1/uploads/evidence/<uuid>.webp", sizeBytes: 184320, mimeType: "image/webp" }`.
* **`GET /api/v1/uploads/evidence/:filename`** *(JWT Authenticated)*:
  * Validasi regex ketat `/^[0-9a-f-]{36}\.(webp|jpg|png)$/` (anti *path traversal*), stream file dengan header `Cache-Control: private, max-age=86400`.
* **`POST /api/v1/stocks/update-condition`**:
  * Body (Zod): `{ itemId: int, locationId: int, fromStatus: 'GOOD'|'SERVICE'|'BROKEN', toStatus: 'GOOD'|'SERVICE'|'BROKEN', qty: int(>=1), note: str(min 5, max 1000), photoUrl?: str, jobCode?: str(<=100), expectedVersion: int(>=1) }`.
  * Refinement Zod: `fromStatus !== toStatus`; jika `toStatus === 'SERVICE' || toStatus === 'BROKEN'` maka `photoUrl` **wajib** berupa path `/api/v1/uploads/evidence/...` yang terverifikasi ada di `StorageService`.
* **`PATCH /api/v1/stocks/remarks`**: `{ itemId, locationId, jobCode?, remarks?, expectedVersion }`.
* **`POST /api/v1/stocks/in`** (`SUPER_ADMIN`, `ADMIN_GUDANG`): `{ itemId, locationId, qty: int(>=1), note: str(min 5), expectedVersion?: int }`.
* **`POST /api/v1/stocks/dispose`** (`SUPER_ADMIN`): `{ itemId, locationId, qty: int(>=1), note: str(min 10), expectedVersion: int }` (hanya mengurangi `qtyBroken`).

## 3.5 Two-Stage Transfer Endpoints

* **`POST /api/v1/transfers`** (`TRANSFER_OUT`):
  `{ itemId: int, fromLocationId: int, toLocationId: int, conditionStatus: 'GOOD'|'SERVICE'|'BROKEN', qty: int(>=1), jobCode?: str(<=100), senderNote: str(min 3, max 1000), expectedVersion: int }`
* **`GET /api/v1/transfers`**:
  Query: `direction?: 'incoming'|'outgoing'|'all'`, `status?: 'IN_TRANSIT'|'RECEIVED'|'REJECTED'|'CANCELLED'`, `page`, `limit`.
* **`POST /api/v1/transfers/:id/receive`**: `{ receiverNote?: str(<=1000) }`
* **`POST /api/v1/transfers/:id/reject`**: `{ receiverNote: str(min 5, max 1000) }` (alasan penolakan wajib)
* **`POST /api/v1/transfers/:id/cancel`**: `{ senderNote?: str(<=1000) }`

## 3.6 Audit Logs, Compliance Export & Master/User Endpoints

* **`GET /api/v1/logs`**: Query `itemId?`, `locationId?`, `actionType?`, `userId?`, `dateFrom?` (ISO date), `dateTo?`, `page`, `limit`.
* **`GET /api/v1/reports/export`**: Query `type: 'stock'|'logs'`, `format: 'xlsx'|'pdf'`, `locationId?`, `categoryId?`, `dateFrom?`, `dateTo?` $\rightarrow$ Binary stream (`application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` atau `application/pdf`).
* **`POST /api/v1/users`** (`SUPER_ADMIN`): `{ username, fullName, password, role, assignedLocationId? }` (otomatis `mustChangePassword = true`).
* **`PATCH /api/v1/users/:id`** (`SUPER_ADMIN`): Ubah nama, role, lokasi, `isActive`, atau reset password (reset password otomatis mencabut seluruh `refresh_tokens` & mengatur `mustChangePassword = true`).
* **`POST /api/v1/users/:id/revoke-sessions`** (`SUPER_ADMIN`): Mencabut seketika seluruh `refresh_tokens` aktif user (`revoked_at = NOW()`) dan mencatat log keamanan.

---

# 4. BACKEND MODULE ALGORITHMS & STATE MACHINES

## 4.1 Auth, `must_change_password` Gate & Refresh Token Reuse Detection

```typescript
// Pseudocode: AuthService.refreshSession(rawRefreshToken)
async function refreshSession(rawToken: string, deviceInfo?: string) {
  const tokenHash = sha256Hex(rawToken);
  const record = await prisma.refreshToken.findUnique({
    where: { tokenHash },
    include: { user: true },
  });

  if (!record) throw new AppError(401, 'AUTH_TOKEN_EXPIRED', 'Sesi tidak valid.');

  // REUSE DETECTION (SRS-SEC-012): token sudah pernah dicabut tetapi dikirim ulang!
  if (record.revokedAt !== null) {
    await prisma.refreshToken.updateMany({
      where: { userId: record.userId, familyId: record.familyId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    logger.warn({ userId: record.userId, familyId: record.familyId }, 'SECURITY_ALERT: Refresh token reuse detected — family revoked');
    throw new AppError(401, 'AUTH_TOKEN_REUSE_DETECTED', 'Aktivitas sesi mencurigakan terdeteksi. Silakan login ulang.');
  }

  if (record.expiresAt < new Date() || !record.user.isActive) {
    throw new AppError(401, 'AUTH_TOKEN_EXPIRED', 'Sesi telah berakhir atau akun nonaktif.');
  }

  // Atomic rotation: revoke old token & issue new token in same family
  const newRawRefresh = randomBytes(48).toString('base64url');
  await prisma.$transaction([
    prisma.refreshToken.update({ where: { id: record.id }, data: { revokedAt: new Date() } }),
    prisma.refreshToken.create({
      data: {
        userId: record.userId,
        familyId: record.familyId,
        tokenHash: sha256Hex(newRawRefresh),
        deviceInfo: deviceInfo ?? record.deviceInfo,
        expiresAt: addDays(new Date(), 7),
      },
    }),
  ]);

  const accessToken = signJwtAccess(record.user); // TTL 15 minutes
  return { accessToken, refreshToken: newRawRefresh, expiresIn: 900 };
}
```

**Middleware `requirePasswordChanged`:** Dipasang pada seluruh route `/api/v1/*` kecuali `/auth/login`, `/auth/logout`, `/auth/refresh`, `/auth/change-password`, `/auth/me`, dan `/health`. Bila `req.user.mustChangePassword === true`, langsung mengembalikan `403 AUTH_MUST_CHANGE_PASSWORD`.

## 4.2 Location RBAC Authorization Guard (`Read Global, Write Local`)

```typescript
// Pseudocode: authorizeLocationWrite(targetLocationId, user, options)
function assertCanWriteLocation(
  user: AuthUser,
  targetLocationId: number,
  options: { allowFieldTech?: boolean } = { allowFieldTech: true }
) {
  if (user.role === 'SUPER_ADMIN') return;
  if (user.role === 'VIEWER') {
    throw new AppError(403, 'RBAC_ROLE_DENIED', 'Akun Viewer hanya memiliki akses baca.');
  }
  if (user.role === 'PETUGAS_LAPANGAN' && !options.allowFieldTech) {
    throw new AppError(403, 'RBAC_ROLE_DENIED', 'Operasi ini hanya diizinkan untuk Admin Gudang atau Super Admin.');
  }
  if (user.assignedLocationId !== targetLocationId) {
    throw new AppError(403, 'RBAC_LOCATION_DENIED', 'Anda hanya berwenang mengubah stok di lokasi tugas Anda.');
  }
}
```

## 4.3 Atomic Stock Condition Update & Optimistic Locking (`version`)

```typescript
// Pseudocode: StockService.updateCondition(dto, user)
async function updateCondition(dto: UpdateConditionDto, user: AuthUser) {
  assertCanWriteLocation(user, dto.locationId, { allowFieldTech: true });

  // ISO 45001 Guard: wajib bukti foto valid saat pindah ke SERVICE atau BROKEN
  if (dto.toStatus === 'SERVICE' || dto.toStatus === 'BROKEN') {
    if (!dto.photoUrl || !(await storageService.exists(extractFilename(dto.photoUrl)))) {
      throw new AppError(400, 'SAFETY_PHOTO_REQUIRED', 'Bukti foto kondisi K3 wajib diunggah untuk status Service atau Broken.');
    }
  }

  return prisma.$transaction(async (tx) => {
    const stock = await tx.itemStock.findUnique({
      where: { itemId_locationId: { itemId: dto.itemId, locationId: dto.locationId } },
    });
    if (!stock) throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Saldo item di lokasi ini tidak ditemukan.');

    const fromField = statusToColumn(dto.fromStatus); // 'qtyGood' | 'qtyService' | 'qtyBroken'
    const toField   = statusToColumn(dto.toStatus);

    if (stock[fromField] < dto.qty) {
      throw new AppError(400, 'INSUFFICIENT_STOCK', `Stok ${dto.fromStatus} hanya tersisa ${stock[fromField]} unit.`);
    }

    const qtyBefore = snapshotOf(stock);

    // Optimistic Locking: update hanya sukses jika version masih sama
    const updated = await tx.itemStock.updateMany({
      where: { id: stock.id, version: dto.expectedVersion, [fromField]: { gte: dto.qty } },
      data: {
        [fromField]: { decrement: dto.qty },
        [toField]: { increment: dto.qty },
        jobCode: dto.jobCode ?? stock.jobCode,
        version: { increment: 1 },
        updatedById: user.id,
      },
    });

    if (updated.count === 0) {
      throw new AppError(409, 'STOCK_VERSION_CONFLICT', 'Data stok baru saja diubah pengguna lain. Muat ulang data terbaru.');
    }

    const freshStock = await tx.itemStock.findUniqueOrThrow({ where: { id: stock.id } });
    await tx.stockLog.create({
      data: {
        itemId: dto.itemId,
        fromLocationId: dto.locationId,
        toLocationId: dto.locationId,
        actionType: 'STATUS_CHANGE',
        statusChanged: `${dto.fromStatus}_TO_${dto.toStatus}`,
        qtyChanged: dto.qty,
        qtyBefore,
        qtyAfter: snapshotOf(freshStock),
        jobCode: dto.jobCode ?? stock.jobCode,
        note: dto.note,
        photoUrl: dto.photoUrl ?? null,
        userId: user.id,
      },
    });

    return freshStock;
  });
}
```

## 4.4 Two-Stage Transfer State Machine & Atomic Transitions

```text
                       ┌───────────────────────────┐
   POST /transfers     │        IN_TRANSIT         │
  ────────────────────►│  (qty moved to source     │
   (Source Location)   │   qty_in_transit)         │
                       └──┬──────────┬──────────┬──┘
                          │          │          │
        POST /:id/receive │          │          │ POST /:id/cancel
        (Target Location) │          │          │ (Source Location / Admin)
                          ▼          │          ▼
                ┌──────────────┐     │    ┌──────────────┐
                │   RECEIVED   │     │    │  CANCELLED   │
                │ (+target qty)│     │    │ (+source qty)│
                └──────────────┘     │    └──────────────┘
                                     │
                    POST /:id/reject │ (Target Location + Wajib Alasan)
                                     ▼
                              ┌──────────────┐
                              │   REJECTED   │
                              │ (+source qty)│
                              └──────────────┘
```

* **Generasi `transferCode`:** `TRF-YYYYMMDD-<4_DIGIT_RANDOM_OR_SEQ>` (unik dengan retry ringan pada collision).
* **Concurrency Protection pada `receive`/`reject`/`cancel`:** Menggunakan pembaruan bersyarat `tx.stockTransfer.updateMany({ where: { id, status: 'IN_TRANSIT' }, data: { status: nextStatus, ... } })`. Bila `count === 0`, langsung mengembalikan `400 TRANSFER_INVALID_STATE` sehingga dua klik bersamaan dari penerima dan pengirim (terima vs batal) tidak pernah memproses mutasi ganda!
* **Target Upsert saat `receive`:** Jika baris `item_stocks` di `toLocationId` belum ada, otomatis dibuat lewat `tx.itemStock.upsert(...)` agar mutasi ke site yang sebelumnya berstok 0 selalu berhasil.

## 4.5 Secure Evidence Upload Pipeline (`Magic Bytes` + `Sharp` EXIF Strip + `StorageService`)

1. **Multer Memory Storage:** Batas keras `limits: { fileSize: 2 * 1024 * 1024 }` (`2 MB`), hanya menerima 1 file (`single('file')`).
2. **Magic-Byte Inspection (`file-type`):** Memeriksa *buffer header* biner asli; menolak bila bukan `image/jpeg`, `image/png`, atau `image/webp` (`415 UPLOAD_INVALID_MAGIC_BYTES`).
3. **Re-Encoding & EXIF/GPS Stripping (`sharp`):**
   ```typescript
   const safeBuffer = await sharp(file.buffer)
     .rotate()                                                         // Auto-orient sesuai EXIF sebelum EXIF dibuang
     .resize(1280, 1280, { fit: 'inside', withoutEnlargement: true })
     .webp({ quality: 80 })                                            // Output WebP bersih — 100% metadata EXIF/GPS terhapus!
     .toBuffer();
   ```
4. **Storage Abstraction (`StorageService`):**
   ```typescript
   export interface StorageService {
     save(filename: string, buffer: Buffer, mimeType: string): Promise<string>;
     getReadStream(filename: string): Promise<NodeJS.ReadableStream>;
     exists(filename: string): Promise<boolean>;
   }
   ```
   Implementasi default `LocalVolumeStorage` memvalidasi `path.resolve(baseDir, safeUuidFilename).startsWith(baseDir)` guna menutup 100% celah *path traversal*.

## 4.6 Safe Excel & PDF Report Generator (Anti Formula Injection)

```typescript
// Anti CSV/Excel Formula Injection (SRS-SEC-014)
const FORMULA_PREFIX = /^[=+\-@\t\r]/;
export function sanitizeSpreadsheetCell(value: string | null | undefined): string {
  if (!value) return '';
  const trimmed = value.toString();
  return FORMULA_PREFIX.test(trimmed) ? `'${trimmed}` : trimmed;
}
```

* **Excel (`exceljs`):** Workbook dengan 2 sheet untuk laporan stok (`Summary 4 Lokasi` + `Detail 531+ Item`), kolom otomatis dibekukan (*frozen header*), seluruh string bebas melalui `sanitizeSpreadsheetCell()`.
* **PDF (`pdfkit`):** Header korporat **PT HIKARI TEKNOLOGI INDONESIA**, subjudul kepatuhan `ISO 9001:2015 & ISO 45001:2018`, metadata filter & waktu cetak WIB (`Asia/Jakarta`), tabel dengan *page header repeat*, dan footer tanda tangan 3 kolom (`Dibuat Oleh`, `Diperiksa QA/HSE`, `Disetujui Manajemen`).

## 4.7 Structured Logging (`Pino`), Redaction & Global Error Handler

* **Pino Config:** `redact: { paths: ['req.headers.authorization', '*.password', '*.currentPassword', '*.newPassword', '*.refreshToken', '*.accessToken'], censor: '[REDACTED]' }`.
* **Error Mapping:** `AppError` $\rightarrow$ status & code terkait; `ZodError` $\rightarrow$ `422 VALIDATION_ERROR`; Prisma `P2002` $\rightarrow$ `409 DUPLICATE_RESOURCE`; Prisma `P2025` $\rightarrow$ `404 RESOURCE_NOT_FOUND`; Error tak terduga $\rightarrow$ `500 INTERNAL_SERVER_ERROR` (pesan generik di produksi, detail lengkap + `requestId` hanya dicatat di log server).

---

# 5. FLUTTER CLIENT LOW-LEVEL DESIGN (DESKTOP & ANDROID)

## 5.1 Flutter Source Tree (`app/lib/`)

```text
app/lib/
├── core/
│   ├── config/server_config_storage.dart     # Simpan & validasi Server Base URL (LAN / Cloud)
│   ├── network/
│   │   ├── dio_client.dart                   # BaseOptions (15s/45s), gzip, X-Request-Id
│   │   ├── auth_interceptor.dart             # QueuedInterceptor + Single-Flight Refresh Lock
│   │   └── api_exception.dart                # Mapping error.code -> pesan ramah Bahasa Indonesia
│   ├── security/secure_token_storage.dart    # flutter_secure_storage (Keystore/DPAPI/libsecret)
│   ├── media/evidence_image_helper.dart      # image_picker + flutter_image_compress (keepExif: false)
│   ├── router/app_router.dart                # GoRouter + Auth/Password/Role guards
│   └── theme/app_theme.dart                  # Material 3 + warna K3 kontras tinggi (#D32F2F/#F57C00/#2E7D32)
├── layouts/
│   ├── adaptive_shell.dart                   # LayoutBuilder breakpoint: >= 900dp Desktop, < 900dp Mobile
│   ├── desktop_shell.dart                    # NavigationRail + Ctrl+K global shortcut
│   └── mobile_shell.dart                     # BottomNavigationBar + Incoming Transfer Badge
└── features/
    ├── auth/         (data, providers, screens: login_screen, change_password_screen, server_config_dialog)
    ├── dashboard/    (data, providers, screens: dashboard_screen, widgets: location_kpi_card)
    ├── inventory/    (data, providers, screens: inventory_list_screen, item_detail_screen, modals: condition_update_modal, transfer_create_modal, stock_in_modal, disposal_modal)
    ├── transfers/    (data, providers, screens: transfers_screen [Incoming/Outgoing tabs])
    ├── logs/         (data, providers, screens: audit_logs_screen, widgets: evidence_photo_lightbox)
    └── master/       (data, providers, screens: master_items_screen, users_management_screen)
```

## 5.2 Single-Flight `Dio` Auth Refresh Interceptor & Degraded Connectivity Handling

* **Single-Flight Refresh Lock:** Menggunakan `QueuedInterceptor` pada `Dio` dan `Completer<String?>` bersama. Jika 3 permintaan paralel (misal Dashboard + Search + Pending Transfers) menerima `401 AUTH_TOKEN_EXPIRED` bersamaan, hanya **1 permintaan** yang memanggil `/api/v1/auth/refresh`; dua lainnya menunggu hasil `Completer` lalu mengulang (*retry*) dengan token baru. Ini mencegah terjadinya *false positive* `AUTH_TOKEN_REUSE_DETECTED`!
* **Degraded Connectivity UX (`SRS-MOD-002`):** Ketika `DioExceptionType.connectionTimeout` / `connectionError` terjadi saat pengguna mengisi form update kondisi atau transfer, *form controller* **tidak mereset field maupun path foto lokal**; aplikasi menampilkan `MaterialBanner` oranye (*"Koneksi server terputus — data formulir aman tersimpan sementara"*) beserta tombol **Coba Kirim Ulang** dengan `X-Idempotency-Key` yang sama.

## 5.3 Riverpod State Providers & Debounced Search Design

| Provider | Tipe | Tanggung Jawab |
| :--- | :--- | :--- |
| `serverConfigProvider` | `AsyncNotifierProvider<String>` | Memuat/menyimpan Base URL + metode `testHealth()` |
| `authControllerProvider` | `AsyncNotifierProvider<AuthState>` | State user aktif (`unauthenticated`, `mustChangePassword`, `authenticated`), login, logout, changePassword |
| `inventoryFilterProvider` | `StateProvider<InventoryFilter>` | Query teks, `categoryId`, `locationId`, `condition`, `page` |
| `inventorySearchProvider` | `AsyncNotifierProvider<PagedItems>` | Memasang `Timer(Duration(milliseconds: 300))` debounce + `CancelToken` Dio untuk membatalkan request usang saat mengetik cepat |
| `dashboardSummaryProvider` | `FutureProvider<DashboardSummary>` | Menyediakan KPI 4 lokasi & angka *badge* transfer masuk |
| `transfersControllerProvider` | `AsyncNotifierProvider<TransfersState>` | Memuat tab *Incoming/Outgoing* & mengeksekusi `create/receive/reject/cancel` lalu otomatis `ref.invalidate(dashboardSummaryProvider)` & `inventorySearchProvider` |
| `stockMutationControllerProvider` | `StateNotifierProvider<MutationState>` | Mengelola flag `isSubmitting` (anti *double-tap*), kompresi & unggah foto bukti, serta mengirim mutasi kondisi/remarks/stock-in/disposal |

## 5.4 `GoRouter` Route Table & Security/Role Guards

| Route Path | Akses Role | Redirect Guard |
| :--- | :--- | :--- |
| `/login` | Public | Bila sudah login & `!mustChangePassword` $\rightarrow$ `/dashboard` (Desktop) atau `/inventory` (Android) |
| `/change-password` | Authenticated | Dipaksa masuk ke sini bila `user.mustChangePassword == true` |
| `/dashboard` | All Auth | Default home Desktop |
| `/inventory` & `/inventory/:id` | All Auth | Default home Android; tombol mutasi hanya aktif bila `canWriteLocation(user, locId)` |
| `/transfers` | All Auth | Menampilkan *Incoming* & *Outgoing*; tombol Terima/Tolak hanya aktif bagi lokasi tujuan / `SUPER_ADMIN` |
| `/logs` | All Auth | *Audit Trail Viewer* + tombol Export Excel/PDF |
| `/master` & `/users` | `SUPER_ADMIN` | Role lain otomatis dialihkan ke `/dashboard` dengan notifikasi akses ditolak |

## 5.5 Component & Screen Blueprints (`DesktopShell` vs `MobileShell`)

* **Desktop (`>= 900 dp`):**
  * `NavigationRail` kiri (`Dashboard`, `Inventaris`, `Transfer` + badge merah, `Audit & Laporan`, serta `Master Data` & `Pengguna` khusus `SUPER_ADMIN`).
  * `CallbackShortcuts` global memetakan `Ctrl+K` / `/` ke `FocusNode` bilah pencarian, dan `Escape` untuk menutup dialog.
  * *DataTable* mendukung baris dapat diperluas (*expandable row*) memperlihatkan matriks 4 lokasi (`WH-1`, `WH-2`, `SITE-PTS`, `SITE-NON-PTS`) beserta tombol aksi sesuai wewenang lokasi.
  * Pratinjau foto bukti menggunakan `Image.network` dengan header `Authorization: Bearer <token>` di dalam `InteractiveViewer` (zoom/pan).
* **Android (`< 900 dp`):**
  * `BottomNavigationBar` 3 tab utama (`Inventaris`, `Transfer` + badge, `Akun`) dengan target sentuh tombol minimal `48 x 48 dp`.
  * Alur cepat **Ubah Kondisi** (target `<= 60 detik`): Pilih item $\rightarrow$ ketuk `Ubah Kondisi` $\rightarrow$ pilih `Service`/`Broken` $\rightarrow$ tombol wajib `Ambil Foto (Kamera)` / `Pilih Galeri` $\rightarrow$ `flutter_image_compress` (`minWidth: 1280, quality: 75, keepExif: false`) $\rightarrow$ isi `note` & `jobCode` $\rightarrow$ ketuk `Simpan` (terkunci selama *loading* + *idempotency key*).
  * Peringatan tegas berwarna merah/oranye bila mengirim transfer barang berstatus `BROKEN`/`SERVICE` (`SRS-SAF-003`).

---

# 6. PYTHON BASELINE EXCEL MIGRATION DESIGN (`HTI-TEIS-MIG-01`)

## 6.1 ETL Pipeline Stages & Normalization Rules

Utilitas `migration/migrate_nov25.py` dirancang **idempoten** (berjalan dalam satu transaksi PostgreSQL, *rollback* total bila satu assertion pun gagal):

1. **Extract:** Membaca *sheet* `Nov 25` dari `2025 NEW ASSET TOOL & EQUIPMENT (2).xlsx` menggunakan `openpyxl` (`data_only=True` agar rumus Excel dibaca nilainya).
2. **Category Detection:** Mendeteksi baris header kategori dari 9 kategori baku (`EQUIPMENT`, `TOOLS`, `ELECTRICAL & PNEUMATIC TOOLS`, `MEASURING TOOLS`, `HAND TOOLS`, `LIFTING AND PULLING TOOLS`, `INVENTARIS WAREHOUSE`, `QUALITY CONTROL (QC) TOOLS`, `INVENTARIS SAFETY`) dan menetapkan `categories.code` (`EQP`..`SFT`).
3. **Unit Standardization Map:**
   ```python
   UNIT_MAP = {
       "UNIT": "UNIT", "UNT": "UNIT", "PCS": "PCS", "PC": "PCS",
       "SET": "SET", "SETS": "SET", "ROLL": "ROLL", "ROL": "ROLL",
       "EA": "EA", "EACH": "EA", "PAIR": "PAIR", "PSG": "PAIR",
       "BOX": "BOX", "BTL": "BTL", "BOTOL": "BTL",
   }
   ```
   Setiap nilai satuan di-`strip().upper()` dan dipetakan via `UNIT_MAP`; nilai tak dikenal dicatat dan menghentikan migrasi (*fail-fast*).
4. **Location Column Normalization Map:**
   * `Warehouse 1` $\rightarrow$ `WH-1` (`Warehouse 1`, `WAREHOUSE`)
   * `Warehouse-2` $\rightarrow$ `WH-2` (`Warehouse 2`, `WAREHOUSE`)
   * `SITE PTS` $\rightarrow$ `SITE-PTS` (`Site PTS`, `SITE`)
   * `SITE NON PTS` $\rightarrow$ `SITE-NON-PTS` (`Site Non PTS`, `SITE`)

## 6.2 Deterministic SKU Generator & `job_code` Regex Parser

* **SKU Generator:** Counter per kategori diurutkan sesuai urutan baris asli Excel `Nov 25` sehingga menghasilkan SKU deterministik `HTI-{CAT_CODE}-{SEQ:04d}` (misal `HTI-EQP-0001`, `HTI-SFT-0012`).
* **Job Code Regex Extractor:** Mengekstrak pola kode proyek PT HTI dari kolom `REMARKS` (contoh: *"1 di job 1p-31-180"*):
  ```python
  JOB_CODE_REGEX = re.compile(r"(?:job\s*[:#-]?\s*)([A-Za-z0-9][A-Za-z0-9\-_/]{2,})", re.IGNORECASE)
  ```
  Teks asli tetap dipertahankan pada `item_stocks.remarks`, sementara kode proyek hasil ekstraksi (uppercase) disimpan pada `item_stocks.job_code`.

## 6.3 Automated Reconciliation Assertion Gate (`531` Items / `12.808` Units)

Skrip `migration/verify_baseline.py` (dipanggil otomatis sebelum `COMMIT`) wajib memverifikasi seluruh persamaan berikut secara tepat:

```python
EXPECTED_TOTALS = {
    "WH-1":         {"good": 8096, "service": 111, "broken": 2242, "total": 10449},
    "WH-2":         {"good": 1830, "service": 8,   "broken": 107,  "total": 1945},
    "SITE-NON-PTS": {"good": 214,  "service": 0,   "broken": 0,    "total": 214},
    "SITE-PTS":     {"good": 200,  "service": 0,   "broken": 0,    "total": 200},
}
assert count_categories == 9
assert count_locations == 4
assert count_active_items == 531
assert grand_good == 10340 and grand_service == 119 and grand_broken == 2349
assert grand_total == 12808
```

Setiap baris `item_stocks` dengan total `> 0` otomatis dicatat ke `stock_logs` dengan `action_type = 'INITIAL_IMPORT'`, `qty_before = null`, `qty_after = {good, service, broken, in_transit: 0}`, dan `note = 'Baseline import Excel Nov 25'`.

---

# 7. INFRASTRUCTURE, DOCKER & ENCRYPTED BACKUP BLUEPRINTS

## 7.1 Hardened Multi-Stage `Dockerfile` (`backend/Dockerfile`)

```dockerfile
# Stage 1: Build TypeScript & Generate Prisma Client
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json prisma ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npx prisma generate && npm run build

# Stage 2: Minimal Production Runtime (Non-Root — SRS-SEC-013)
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
RUN mkdir -p /app/storage/evidence && chown -R node:node /app
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/api/v1/health || exit 1
CMD ["node", "dist/server.js"]
```

## 7.2 Isolated `docker-compose.yml` Network & Volume Specification

```yaml
services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - hti_pg_data:/var/lib/postgresql/data
      - ./infra/scripts/init_db_roles.sql:/docker-entrypoint-initdb.d/99_roles.sql:ro
    networks: [hti_internal_net] # Port 5432 TIDAK diekspos ke host publik!
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    logging:
      driver: json-file
      options: { max-size: "20m", max-file: "5" }

  api:
    build: ./backend
    restart: unless-stopped
    read_only: true
    tmpfs: ["/tmp"]
    env_file: .env
    depends_on:
      postgres: { condition: service_healthy }
    volumes:
      - hti_evidence_data:/app/storage/evidence
    networks: [hti_internal_net]
    logging:
      driver: json-file
      options: { max-size: "20m", max-file: "5" }

  nginx:
    image: nginx:1.26-alpine
    restart: unless-stopped
    ports: ["80:80", "443:443"]
    volumes:
      - ./infra/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./infra/certs:/etc/nginx/certs:ro
    depends_on:
      api: { condition: service_healthy }
    networks: [hti_edge_net, hti_internal_net]
    logging:
      driver: json-file
      options: { max-size: "20m", max-file: "5" }

networks:
  hti_edge_net:
  hti_internal_net:
    internal: true

volumes:
  hti_pg_data:
  hti_evidence_data:
```

## 7.3 Nginx TLS Reverse Proxy Blueprint (`infra/nginx/nginx.conf`)

* Redirect permanen port `80` $\rightarrow$ `https://$host$request_uri` (`301`).
* TLS `TLSv1.2 TLSv1.3`, HSTS `max-age=31536000; includeSubDomains`, `gzip on` (`application/json`).
* `client_max_body_size 3M;` (mengizinkan overhead multipart foto `2 MB`).
* Meneruskan `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`, dan `X-Request-Id` ke `http://api:3000`.
* Mendukung mode pemeliharaan instan via file flag `/etc/nginx/maintenance.on` $\rightarrow$ mengembalikan JSON `503 SERVICE_MAINTENANCE` + header `Retry-After: 300`.

## 7.4 Automated `AES-256` Encrypted Backup & Restore Algorithms

* **`infra/scripts/backup.sh` (Cron `0 2 * * *` WIB):**
  1. `pg_dump -Fc` dari kontainer `postgres` ke berkas sementara `/tmp/hti_db_${TS}.dump`.
  2. Arsip volume foto `hti_evidence_data` ke `/tmp/hti_evidence_${TS}.tar.gz`.
  3. Enkripsi kedua berkas menggunakan `openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -pass env:BACKUP_ENC_KEY` (atau `gpg --symmetric --cipher-algo AES256`) menuju `hti_backup_data/`.
  4. Buat berkas checksum `.sha256`, hapus file plaintext sementara di `/tmp`, lalu hapus arsip berumur `> 30 hari` (`find -mtime +30 -delete`).
  5. Periksa utilisasi disk (`df -P`); catat peringatan bila penggunaan `> 80%`.
* **`infra/scripts/restore.sh` (Target RTO $\le 2\text{ jam}$):**
  1. Aktifkan mode pemeliharaan Nginx, verifikasi checksum `.sha256`, dekripsi arsip `.dump.enc` dan `.tar.gz.enc`.
  2. Hentikan kontainer `api`, jalankan `pg_restore --clean --if-exists` ke `postgres`, ekstrak ulang volume `hti_evidence_data` dengan kepemilikan UID `node`.
  3. Nyalakan ulang `api`, verifikasi `GET /api/v1/health`, dan matikan mode pemeliharaan.

---

# 8. LOW-LEVEL TESTING STRATEGY & TEST CASE MATRIX

| Lapisan Uji | Tool | Skenario Pengujian Wajib | Target Kelulusan |
| :--- | :--- | :--- | :--- |
| **Backend Unit Tests** | Jest / Vitest | `sanitizeSpreadsheetCell()` (uji `=CMD\|`, `+1`, `-2`, `@SUM`, `\t=`), `statusToColumn()`, `assertCanWriteLocation()`, Zod schemas, generator SKU | `100%` lulus, coverage logika inti $\ge 80\%$ |
| **Backend Integration Tests** | Jest + Supertest + Test PostgreSQL | • Seluruh matriks 4 role (`SUPER_ADMIN`, `ADMIN_GUDANG`, `PETUGAS_LAPANGAN`, `VIEWER`)<br>• *First-login* `must_change_password` block & change<br>• *Refresh token reuse detection* & `revoke-sessions`<br>• Blokir `GOOD -> BROKEN` tanpa foto (`400`)<br>• Konkurensi paralel (`Promise.all` 2 request versi sama $\rightarrow$ 1 `200`, 1 `409`)<br>• Siklus penuh Transfer 2 Tahap (`IN_TRANSIT` $\rightarrow$ `RECEIVED` / `REJECTED` / `CANCELLED`)<br>• Upload file `.exe`/`.php` berkedok `.jpg` (`415`) + verifikasi output WebP bebas EXIF<br>• Uji DB role `hti_app` ditolak saat `DELETE FROM stock_logs` | `100%` lulus di CI; total unit sistem tetap invarian sebelum & sesudah seluruh uji transfer |
| **Load & Performance Tests** | `k6` (`tests/load/`) | 50 *virtual users* selama 3 menit pada DB terisi 10.000 item & 100.000 log (`search`, `dashboard`, `update-condition`) | Search `p95 <= 300 ms`, `p99 <= 500 ms`; error rate `< 0.1%` |
| **Flutter Unit & Widget Tests** | `flutter_test` + `mocktail` | • Single-flight `Dio` refresh lock (3 request paralel `401` hanya memicu 1 kali `/auth/refresh`)<br>• Form *Update Kondisi* menolak submit ke `Broken`/`Service` bila foto kosong<br>• `AdaptiveShell` merender `DesktopShell` di `1280x800` dan `MobileShell` di `390x844`<br>• Preservasi state form saat simulasi error koneksi | `100%` lulus + `dart analyze` 0 error |
| **Migration & DR Tests** | Python `pytest` + Docker Drill | • Eksekusi `migrate_nov25.py` + `verify_baseline.py`<br>• *Backup & Restore Drill* menggunakan `backup.sh` & `restore.sh` | Tepat `531` item & `12.808` unit; restore selesai `< 2 jam` tanpa kehilangan data/foto |
