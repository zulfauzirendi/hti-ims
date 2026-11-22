# HIGH-LEVEL DESIGN (HLD)
## PT HTI TOOL & EQUIPMENT INVENTORY SYSTEM (HTI-TEIS)

---

| Atribut Dokumen | Keterangan |
| :--- | :--- |
| **Document Identifier** | `HTI-HLD-TEIS-001` |
| **Standard Reference** | ISO/IEC/IEEE 42010 & MIL-STD-498 (Software Design Description — Architectural View) |
| **SRS Reference** | `HTI-SRS-TEIS-001` Version `1.1` |
| **Version** | `1.0` (Baseline Architecture) |
| **Date** | 22 November 2026 |
| **Classification** | INTERNAL CONFIDENTIAL — PT HIKARI TEKNOLOGI INDONESIA |
| **Prepared For** | Manajemen, Tim Operasional & Tim Engineering — **PT Hikari Teknologi Indonesia (PT HTI)** |
| **Prepared By** | Systems Architecture & Software Engineering Team |

---

## LEMBAR PENGESAHAN (APPROVAL SHEET)

| Peran | Nama / Jabatan | Tanda Tangan | Tanggal |
| :--- | :--- | :--- | :--- |
| **Approved (Lead Architect)** | Systems & Solutions Architect | __________________________ | ____ / ____ / 2026 |
| **Accepted (Project Manager)** | Software Project Manager | __________________________ | ____ / ____ / 2026 |
| **Reviewed (Security & ISO QA)** | ISO 9001 / 45001 & Security Reviewer | __________________________ | ____ / ____ / 2026 |

---

## RECORD OF CHANGES

| Version | Date | Section | Change Type (`A`/`M`/`D`) | Description | Author |
| :---: | :---: | :--- | :---: | :--- | :--- |
| `1.0` | 22 Nov 2026 | Seluruh Dokumen (`1`–`9`) | `A` | Penyusunan awal dokumen *High-Level Design* (HLD) mencakup Arsitektur C4 (Context, Container, Component), Arsitektur Data, Alur End-to-End, Arsitektur Keamanan *Defense-in-Depth*, Topologi Hybrid Docker, dan *Architecture Decision Records* (ADR). | Systems Architecture Team |

---

## TABLE OF CONTENTS

1. **INTRODUCTION & ARCHITECTURAL DRIVERS**
   - 1.1 Purpose & Scope
   - 1.2 Key Architectural Drivers & Quality Goals
2. **SYSTEM CONTEXT & CONTAINER ARCHITECTURE (C4 LEVEL 1 & 2)**
   - 2.1 System Context Diagram (C4 Level 1)
   - 2.2 Container Architecture Diagram (C4 Level 2)
   - 2.3 Container Responsibilities Summary
3. **LOGICAL COMPONENT ARCHITECTURE (C4 LEVEL 3)**
   - 3.1 Backend Modular Monolith (`HTI-TEIS-CSCI-01`)
   - 3.2 Flutter Shared-Core Cross-Platform Client (`HTI-TEIS-CSCI-02`)
4. **HIGH-LEVEL DATA ARCHITECTURE**
   - 4.1 Conceptual Entity Relationship Diagram (ERD)
   - 4.2 Data Classification, Partitioning & Lifecycle Strategy
5. **END-TO-END OPERATIONAL FLOWS**
   - 5.1 Authentication, First-Login & Refresh Token Rotation Flow
   - 5.2 Instant Multi-Location Search Flow
   - 5.3 ISO 45001 Field Condition Update & Photo Evidence Flow
   - 5.4 Two-Stage Inter-Location Stock Transfer Flow
   - 5.5 ISO 9001 Audit Trail & Safe Compliance Export Flow
6. **SECURITY ARCHITECTURE (DEFENSE-IN-DEPTH & STRIDE)**
   - 6.1 Six-Layer Security Architecture
   - 6.2 Threat Model Summary (STRIDE Mitigation Matrix)
7. **DEPLOYMENT & INFRASTRUCTURE ARCHITECTURE (HYBRID DOCKER)**
   - 7.1 Dual-Mode Deployment Topology (Cloud VPS vs On-Premise LAN/VPN)
   - 7.2 Docker Network Isolation & Volume Strategy
   - 7.3 High Availability, Encrypted Backup & Observability Architecture
8. **ARCHITECTURE DECISION RECORDS (ADRs)**
9. **HLD-TO-SRS ARCHITECTURAL TRACEABILITY**

---

# 1. INTRODUCTION & ARCHITECTURAL DRIVERS

## 1.1 Purpose & Scope

Dokumen *High-Level Design* (HLD) ini mendefinisikan arsitektur makro, batas komponen, interaksi antarsistem, model keamanan *defense-in-depth*, dan topologi deployment untuk **PT HTI Tool & Equipment Inventory System (HTI-TEIS)**. Dokumen ini menjadi jembatan langsung antara kebutuhan bisnis/non-fungsional pada **[SRS `HTI-SRS-TEIS-001 v1.1`](SRS_PT_HTI_Tool_Equipment_Inventory_System.md)** dan spesifikasi teknis rinci tingkat modul/kode pada **[LLD `HTI-LLD-TEIS-001 v1.0`](LLD_PT_HTI_Tool_Equipment_Inventory_System.md)**.

Ruang lingkup arsitektur meliputi tiga konfigurasi utama:
1. **`HTI-TEIS-CSCI-01` (Backend API & Data Platform):** Layanan REST API (Node.js 20 LTS, TypeScript, Express, Prisma ORM), Basis Data Relasional (PostgreSQL 16), Reverse Proxy (Nginx TLS), Media Storage, dan Backup Sidecar di dalam ekosistem Docker Compose.
2. **`HTI-TEIS-CSCI-02` (Flutter Cross-Platform Client):** Satu *codebase* aplikasi Flutter (Dart 3.x) yang menghasilkan aplikasi Desktop native (**Windows/Linux**) dan aplikasi Mobile (**Android Min SDK 26**).
3. **`HTI-TEIS-MIG-01` (Baseline ETL Migrator):** Utilitas Python 3 terisolasi untuk migrasi dan rekonsiliasi 100% data historis Excel *sheet* `Nov 25` (`531` item, `12.808` unit, 4 lokasi, 9 kategori).

## 1.2 Key Architectural Drivers & Quality Goals

Desain arsitektur dibentuk oleh 7 pendorong kualitas utama (*Architectural Significant Requirements* / ASR) dari SRS:

| Driver ID | Quality Attribute | Target Terukur (dari SRS v1.1) | Keputusan Arsitektural Utama |
| :--- | :--- | :--- | :--- |
| `ASR-01` | **Search Performance** | Pencarian lintas 4 lokasi `p95 <= 300 ms`, `p99 <= 500 ms` (hingga 10.000 item & 50 user) | PostgreSQL `pg_trgm` GIN index + query terpaginasi + Gzip/Brotli + client `300 ms` debounce |
| `ASR-02` | **Location RBAC & Accountability** | Penegakan *Read Global, Write Local* tanpa celah lintas lokasi | Alur **Transfer 2 Tahap** (`IN_TRANSIT` $\rightarrow$ `RECEIVED`/`REJECTED`/`CANCELLED`) + middleware lokasi server-side |
| `ASR-03` | **ISO 9001 Data Integrity** | 0 saldo negatif, 0 *race condition*, *audit trail* imutabel (retensi $\ge 5$ tahun) | Transaksi ACID Prisma + *Optimistic Locking* (`version` / HTTP `409`) + `stock_logs` *append-only* + *soft delete* |
| `ASR-04` | **ISO 45001 Safety Proof** | Wajib foto bukti fisik untuk status `Service`/`Broken`, bebas metadata EXIF/GPS | Pipeline kompresi klien + validasi *magic bytes* + `sharp` EXIF strip + akses gambar ber-JWT |
| `ASR-05` | **Enterprise Security** | Kepatuhan OWASP ASVS L2, MASVS, CIS Docker, dan UU PDP No. 27/2022 | TLS 1.2/1.3, Argon2id, JWT Refresh Rotation + Reuse Detection, Remote Force-Logout, non-root Docker, DB tertutup publik |
| `ASR-06` | **Hybrid Portability** | Dapat di-deploy di **Cloud VPS** maupun **Server Lokal On-Premise PT HTI** tanpa ubah kode | Docker Compose standar + konfigurasi *Server Base URL* dinamis di Desktop & Android + abstraksi `StorageService` |
| `ASR-07` | **Operational Resilience** | Availability $\ge 99.5\%$, RPO $\le 24\text{h}$, RTO $\le 2\text{h}$, aman saat sinyal site putus | Backup otomatis terenkripsi `AES-256`/GPG + *structured logging* (`X-Request-Id`) + *degraded connectivity retry UX* |

---

# 2. SYSTEM CONTEXT & CONTAINER ARCHITECTURE (C4 LEVEL 1 & 2)

## 2.1 System Context Diagram (C4 Level 1)

Diagram berikut menggambarkan interaksi antara empat kelompok pengguna PT HTI pada 4 lokasi fisik dengan sistem HTI-TEIS dan sumber data eksternal:

```text
  ┌──────────────────────────┐    ┌──────────────────────────┐
  │   SUPER_ADMIN (IT/Ops)   │    │  VIEWER (Pak Hanif, Vika)│
  │ Master Data, Users, All  │    │  Monitoring, Audit, PDF  │
  └────────────┬─────────────┘    └────────────┬─────────────┘
               │ Desktop (Win/Linux)           │ Desktop (Win/Linux)
               └──────────────┬────────────────┘
                              ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │         PT HTI TOOL & EQUIPMENT INVENTORY SYSTEM (HTI-TEIS)         │
  │  • Global Multi-Location Search (4 Lokasi, 9 Kategori, 531+ Item)   │
  │  • Real-Time Stock Balance & ISO 45001 Condition + Photo Evidence   │
  │  • 2-Stage Inter-Location Transfer Engine (IN_TRANSIT Workflow)     │
  │  • ISO 9001 Immutable Audit Trail & Excel/PDF Compliance Reporting  │
  └──────────────┬───────────────────────────────────────┬──────────────┘
                 ▲                                       ▲
                 │ Desktop / Android                     │ Android (Field)
  ┌──────────────┴───────────┐            ┌──────────────┴──────────────┐
  │ ADMIN_GUDANG (WH-1/WH-2) │            │ PETUGAS_LAPANGAN            │
  │ Stock In, Status, Kirim  │            │ (SITE-PTS / SITE-NON-PTS)   │
  │ & Terima Transfer Gudang │            │ Status+Foto, Job Code, Trf  │
  └──────────────────────────┘            └─────────────────────────────┘
                 ▲
                 │ One-time Baseline ETL (Nov 25: 531 items / 12.808 units)
  ┌──────────────┴──────────────────────────────────────────────────────┐
  │ Legacy Excel Asset Register: 2025 NEW ASSET TOOL & EQUIPMENT (2).xlsx│
  └─────────────────────────────────────────────────────────────────────┘
```

## 2.2 Container Architecture Diagram (C4 Level 2)

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CLIENT TIER (END-USER DEVICES)                       │
├──────────────────────────────────────┬──────────────────────────────────────┤
│   Flutter Desktop App (Win / Linux)  │   Flutter Android App (Min SDK 26)   │
│   • DesktopShell (>= 900dp)          │   • MobileShell (< 900dp)            │
│   • Windows DPAPI / Linux libsecret  │   • Android Keystore (SecureStorage) │
│   • Local File Save (.xlsx / .pdf)   │   • Camera/Gallery + Image Compress  │
└──────────────────┬───────────────────┴──────────────────┬───────────────────┘
                   │ HTTPS (TLS 1.2/1.3)                  │ HTTPS (TLS 1.2/1.3)
                   │ JSON REST + Multipart                │ JSON REST + Multipart
                   └──────────────────┬───────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│              DOCKER HOST (CLOUD VPS OR ON-PREMISE SERVER PT HTI)            │
│                                                                             │
│  [edge_net: External Port 80/443]                                           │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Nginx Reverse Proxy Container (nginx:1.26-alpine)                    │  │
│  │  • TLS Termination & HTTP->HTTPS 301   • Gzip/Brotli Compression      │  │
│  │  • Body Size Guard (<= 3 MB)           • Security Headers & Proxy     │  │
│  └──────────────────────────────────┬────────────────────────────────────┘  │
│                                     │ HTTP Internal (:3000)                 │
│  [internal_net: Docker internal=true — NO PUBLIC PORT EXPOSURE]             │
│  ┌──────────────────────────────────▼────────────────────────────────────┐  │
│  │  Backend API Container (node:20-alpine, USER node [non-root])         │  │
│  │  • Express + TypeScript + Zod + Prisma ORM + Sharp + ExcelJS + PDFKit │  │
│  │  • JWT Auth/Refresh Rotation + Location RBAC + Pino JSON Logger       │  │
│  └──────────────┬───────────────────────────────────────┬────────────────┘  │
│                 │ TCP :5432 (Internal Only)             │ POSIX / S3 Iface  │
│  ┌──────────────▼──────────────────┐     ┌──────────────▼────────────────┐  │
│  │ PostgreSQL 16 (postgres:16-alp) │     │ Persistent Volume             │  │
│  │ • pg_trgm GIN & B-Tree Indexes  │     │ /app/storage/evidence/*.webp  │  │
│  │ • Volume: pg_data               │     │ (UUID names, EXIF stripped)   │  │
│  └──────────────┬──────────────────┘     └──────────────┬────────────────┘  │
│                 │ Daily 02:00 WIB                       │ Daily 02:00 WIB   │
│  ┌──────────────▼───────────────────────────────────────▼────────────────┐  │
│  │  Backup Cron Job / Sidecar (pg_dump -Fc + tar + AES-256/GPG Encrypt)  │  │
│  │  • 30-Day Rolling Retention -> backup_vol + Optional Offsite Sync     │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 2.3 Container Responsibilities Summary

| Container / Unit | Teknologi | Eksposur Jaringan | Tanggung Jawab Utama |
| :--- | :--- | :--- | :--- |
| **Desktop & Android Client** | Flutter 3.24+ (Dart 3.5+) | Outbound HTTPS ke Nginx | Presentasi adaptif, validasi formulir, kompresi foto lapangan, penyimpanan token aman OS, konfigurasi Server URL. |
| **Nginx Reverse Proxy** | `nginx:1.26-alpine` | Port `80` (redirect) & `443` (TLS) | Terminasi TLS 1.2/1.3, kompresi respons, batas ukuran unggahan, penerusan header `X-Forwarded-For` & `X-Request-Id`. |
| **HTI Backend API** | `node:20-alpine` (non-root) | Internal `:3000` saja | Autentikasi JWT, RBAC lokasi, logika bisnis stok & transfer 2 tahap, validasi & strip EXIF foto, generator Excel/PDF, audit logging. |
| **PostgreSQL Database** | `postgres:16-alpine` | Internal `:5432` saja | Penyimpanan relasional ACID, constraint integritas (`CHECK >= 0`), indeks pencarian trigram `pg_trgm`, *ledger* audit `stock_logs`. |
| **Evidence Storage** | Docker Volume (abstraksi `StorageService`) | Tidak diekspos web publik | Menyimpan file foto bukti K3 berformat WebP/JPEG bernama UUID yang hanya dapat diakses melalui endpoint API ber-JWT. |
| **Backup Sidecar / Cron** | Alpine + `postgresql-client` + `openssl`/`gpg` | Internal DB read + backup volume | Menjalankan backup harian otomatis terenkripsi `AES-256` dan pembersihan rotasi 30 hari (`RPO <= 24h`). |

---

# 3. LOGICAL COMPONENT ARCHITECTURE (C4 LEVEL 3)

## 3.1 Backend Modular Monolith (`HTI-TEIS-CSCI-01`)

Backend dibangun menggunakan pola **Layered Modular Monolith** agar pengembangan cepat, transaksi ACID lintas modul (Stok + Transfer + Audit Log) berjalan dalam satu koneksi database tanpa overhead *distributed transactions*, namun tetap rapi dan mudah diuji secara terisolasi.

```text
┌────────────────────────────────────────────────────────────────────────────┐
│                        HTTP PIPELINE (EXPRESS)                             │
│  RequestId -> PinoHttpLogger -> Helmet -> CORS -> RateLimiter -> JSON/Body │
└─────────────────────────────────────┬──────────────────────────────────────┘
                                      ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                   ROUTE & SECURITY GUARD LAYER                             │
│  Zod Schema Validator -> authenticateJwt -> enforcePasswordChanged ->      │
│  authorizeRoles / authorizeLocationWrite (Read Global, Write Local)        │
└─────────────────────────────────────┬──────────────────────────────────────┘
                                      ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                        DOMAIN SERVICE MODULES                              │
│ ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ │
│ │AuthService │ │ItemService │ │StockService│ │TransferSvc │ │ReportSvc   │ │
│ │(Argon2id,  │ │(pg_trgm    │ │(Condition, │ │(2-Stage    │ │(ExcelJS    │ │
│ │JWT Family) │ │Search,SKU) │ │Opt-Locking)│ │IN_TRANSIT) │ │+ PDFKit)   │ │
│ └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ │
│ ┌─────┴──────────────┴──────────────┴──────────────┴──────────────┴──────┐ │
│ │ AuditLogService (Append-Only ISO 9001)  │ MediaService (Sharp + EXIF)  │ │
│ └────────────────────┬────────────────────┴──────────────┬───────────────┘ │
└──────────────────────┼───────────────────────────────────┼─────────────────┘
                       ▼                                   ▼
┌──────────────────────────────────────┐   ┌─────────────────────────────────┐
│ Prisma ORM Data Access Layer         │   │ StorageService (Interface)      │
│ • ACID $transaction                  │   │ • LocalVolumeStorage (Default)  │
│ • Parameterized Queries              │   │ • S3MinioStorage (Future-Ready) │
└──────────────────────────────────────┘   └─────────────────────────────────┘
```

### Tanggung Jawab Setiap Modul Backend
1. **`auth` Module:** Verifikasi Argon2id/bcrypt, penerbitan JWT Access (`15m`) & Refresh (`7d`), rotasi token, deteksi penggunaan ulang token (*reuse detection* $\rightarrow$ cabut seluruh keluarga sesi), alur `must_change_password`, dan endpoint *force-logout* admin.
2. **`items` & `master` Modules:** Pencarian trigram lintas lokasi, auto-generasi SKU (`HTI-<CAT>-<SEQ>`), CRUD kategori/lokasi/item dengan *soft delete* tervalidasi (menolak hapus bila stok `> 0` atau ada transfer `IN_TRANSIT`).
3. **`stocks` Module:** Transisi status kondisi (`Good`/`Service`/`Broken`), validasi wajib `photo_url` + `note` (ISO 45001), pembaruan `job_code` & `remarks`, `Stock In`, dan `Disposal` — seluruhnya dalam transaksi Prisma + *optimistic locking* (`version`).
4. **`transfers` Module:** Mesin status (*state machine*) 2 tahap (`IN_TRANSIT` $\rightarrow$ `RECEIVED` / `REJECTED` / `CANCELLED`) yang mengelola pemindahan kuantitas secara atomik antara `qty_<condition>` dan `qty_in_transit`.
5. **`uploads` Module:** Memvalidasi *magic bytes*, menghapus seluruh metadata EXIF/GPS & menormalisasi dimensi gambar via `sharp`, menyimpan via `StorageService`, dan menyajikan aliran file terautentikasi JWT.
6. **`logs` & `reports` Modules:** Pencatatan *audit trail* imutabel beserta *snapshot* JSONB sebelum/sesudah, kueri filterable riwayat log, serta generator `.xlsx` (dengan sanitasi anti *formula injection*) dan `.pdf` (kop resmi PT HTI).
7. **`users` Module:** Manajemen siklus hidup akun, penetapan lokasi tugas (`assigned_location_id`), reset password (mengaktifkan `must_change_password`), dan pencabutan sesi perangkat hilang.

## 3.2 Flutter Shared-Core Cross-Platform Client (`HTI-TEIS-CSCI-02`)

```text
┌────────────────────────────────────────────────────────────────────────────┐
│                   ADAPTIVE PRESENTATION LAYER                              │
│ ┌───────────────────────────────────┐ ┌──────────────────────────────────┐ │
│ │ DesktopShell (Width >= 900 dp)    │ │ MobileShell (Width < 900 dp)     │ │
│ │ • NavigationRail + Top Search     │ │ • BottomNav + Transfer Badge     │ │
│ │ • 4-Location KPI & DataTable      │ │ • Field Card List + Filter Chips │ │
│ │ • Action Modals + Ctrl+K Shortcut │ │ • Quick Status + Camera Capture  │ │
│ │ • Audit Lightbox + Export Dialog  │ │ • 1-Tap Receive/Reject Transfer  │ │
│ └─────────────────┬─────────────────┘ └─────────────────┬────────────────┘ │
└───────────────────┼─────────────────────────────────────┼──────────────────┘
                    └──────────────────┬──────────────────┘
                                       ▼
┌────────────────────────────────────────────────────────────────────────────┐
│               SHARED FEATURE STATE & DOMAIN LAYER (RIVERPOD)               │
│  AuthController │ DashboardProvider │ InventorySearchProvider (300ms deb.) │
│  StockMutationController │ TransferController │ AuditLogs & Master Notifier│
└──────────────────────────────────────┬─────────────────────────────────────┘
                                       ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                        SHARED CORE INFRASTRUCTURE                          │
│  GoRouter (Auth/Role/Password Guards) │ Dio Client (Single-Flight Refresh) │
│  ServerConfigStorage (LAN/Cloud URL)  │ FlutterSecureStorage (OS Keystore) │
│  ImageCompressor (<=1280px, no EXIF)  │ Connectivity & Retry Banner Engine │
└────────────────────────────────────────────────────────────────────────────┘
```

---

# 4. HIGH-LEVEL DATA ARCHITECTURE

## 4.1 Conceptual Entity Relationship Diagram (ERD)

```text
┌───────────────────┐           ┌───────────────────────┐
│    categories     │ 1       N │         items         │
│───────────────────├──────────►│───────────────────────│
│ PK id             │ RESTRICT  │ PK id                 │
│ UQ code (EQP,..)  │           │ UQ item_code (SKU)    │
│ UQ name           │           │ FK category_id        │
└───────────────────┘           │    description, spec  │
                                │    unit, is_active    │
┌───────────────────┐           │    deleted_at         │
│     locations     │           └───────┬──────┬────────┘
│───────────────────│                   │1     │1
│ PK id             │                   │      └──────────────────────────┐
│ UQ code (WH-1,..) │                   │N                                │N
│ UQ name           │   ┌───────────────▼────────────────┐   ┌────────────▼───────────────┐
│    location_type  │ 1 │          item_stocks           │   │      stock_transfers       │
│    is_active      ├──►│────────────────────────────────│   │────────────────────────────│
└────┬─────────┬────┘ N │ PK id                          │   │ PK id                      │
     │1        │        │ UQ (item_id, location_id)      │   │ UQ transfer_code           │
     │         │        │    qty_good, qty_service (>=0) │   │ FK item_id (RESTRICT)      │
     │         │        │    qty_broken, qty_in_transit  │   │ FK from_location_id        │
     │         │        │    job_code, remarks           │   │ FK to_location_id          │
     │         │        │    version (Optimistic Lock)   │   │    condition_status, qty   │
     │         │        │ FK updated_by -> users.id      │   │    status (IN_TRANSIT|...) │
     │         │        └────────────────────────────────┘   │ FK sent_by, received_by    │
     │         │                                             └────────────┬───────────────┘
     │         │0..N                                                      │0..1
     │    ┌────▼──────────────────┐     1         N ┌─────────────────────▼───────────────┐
     │    │         users         │◄────────────────┤             stock_logs              │
     │    │───────────────────────│ SET NULL        │─────────────────────────────────────│
     │    │ PK id                 │                 │ PK id (APPEND-ONLY / IMMUTABLE)     │
     │    │ UQ username           │                 │ FK item_id, from_loc, to_loc        │
     │    │    password_hash      │                 │    action_type, status_changed      │
     │    │    full_name, role    │                 │    qty_changed                      │
     │    │ FK assigned_loc_id    │                 │    qty_before (JSONB)               │
     │    │    must_change_pwd    │                 │    qty_after  (JSONB)               │
     │    │    is_active          │                 │    job_code, note, photo_url        │
     │    └───────────┬───────────┘                 │ FK transfer_id, user_id, created_at │
     │                │1                            └─────────────────────────────────────┘
     │                │N (CASCADE)
     │    ┌───────────▼───────────┐
     │    │    refresh_tokens     │
     │    │───────────────────────│
     │    │ PK id                 │
     │    │ FK user_id            │
     │    │ UQ token_hash         │
     │    │    family_id          │
     │    │    device_info        │
     │    │    expires_at,revoked │
     │    └───────────────────────┘
     └──► (from_location_id / to_location_id on stock_transfers & stock_logs)
```

## 4.2 Data Classification, Partitioning & Lifecycle Strategy

| Kelas Data | Entitas Terkait | Pola Akses | Kebijakan Mutasi & Retensi |
| :--- | :--- | :--- | :--- |
| **Master Reference** | `categories`, `locations`, `items` | Read-heavy, jarang berubah | Dikelola `SUPER_ADMIN`. `items` wajib *soft delete* (`is_active = FALSE`, `deleted_at`) demi integritas referensi historis ISO 9001. |
| **Operational Ledger (Hot)** | `item_stocks`, `stock_transfers` | Read/Write bersamaan lintas lokasi | Wajib transaksi ACID + *optimistic locking* (`version`). Saldo dijaga ketat `>= 0` di level aplikasi dan DB `CHECK`. |
| **Immutable Audit Trail** | `stock_logs` | Write-append & Read-filterable | **Append-only** (DB user aplikasi tidak diberi hak `UPDATE`/`DELETE` pada tabel ini). Retensi $\ge 5$ tahun. |
| **Security & Session** | `users`, `refresh_tokens` | Auth-critical, sensitif (UU PDP) | Kata sandi ter-hash Argon2id; refresh token ter-hash SHA-256; token kedaluwarsa `> 30 hari` dibersihkan berkala. |
| **Binary Safety Evidence** | Volume `evidence_storage` (`*.webp`/`*.jpg`) | Write-once, Read via JWT proxy | Berkas bernama UUID v4, bebas EXIF/GPS, batas `<= 2 MB`, ikut tercadangkan harian terenkripsi `AES-256`, retensi $\ge 5$ tahun. |

---

# 5. END-TO-END OPERATIONAL FLOWS

## 5.1 Authentication, First-Login & Refresh Token Rotation Flow

```text
Client (Desktop/Android)           Backend API (/api/v1/auth)             PostgreSQL
       │                                      │                                │
       │ 1. POST /auth/login (user, pass)     │                                │
       ├─────────────────────────────────────►│ 2. Fetch user & verify Argon2id│
       │                                      ├───────────────────────────────►│
       │                                      │ 3. Check is_active == TRUE     │
       │                                      │ 4. Issue Access(15m) +         │
       │                                      │    Refresh(7d, family_id)      │
       │                                      ├──── Store SHA-256 hash ───────►│
       │ 5. 200 OK {tokens, mustChangePwd}    │                                │
       │◄─────────────────────────────────────┤                                │
       │ [If mustChangePwd == true -> Force /auth/change-password screen]      │
       │                                      │                                │
       │ --- 15 mins later: Access Expired ---│                                │
       │ 6. POST /auth/refresh (refreshToken) │                                │
       ├─────────────────────────────────────►│ 7. Lookup hash in DB           │
       │                                      ├─── IF revoked_at != NULL: ────►│
       │                                      │    REUSE DETECTED! Revoke ALL  │
       │                                      │    tokens of family/user + Log │
       │                                      │─── ELSE: Revoke old, issue new─►│
       │ 8. 200 OK {newAccess, newRefresh}    │                                │
       │◄─────────────────────────────────────┤                                │
```

## 5.2 Instant Multi-Location Search Flow

1. Pengguna mengetik kata kunci (misal `"chain block 3 ton"`) pada bilah pencarian Desktop (`Ctrl+K`) atau Android.
2. Klien menunggu jeda *debounce* `300 ms` lalu mengirim `GET /api/v1/items/search?q=chain+block+3+ton&page=1&limit=20`.
3. Backend memvalidasi query dengan Zod, mengeksekusi pencarian menggunakan indeks GIN `pg_trgm` pada `items.description` dan `items.specification` (plus exact/prefix match `items.item_code`) untuk item berstatus `is_active = TRUE`.
4. Hasil 20 item di-*join* dengan `item_stocks` dan `locations` untuk merakit matriks 4 lokasi (`WH-1`, `WH-2`, `SITE-PTS`, `SITE-NON-PTS`) dalam satu kueri teroptimasi (`<= 2` roundtrip SQL, target total `p95 <= 300 ms`).
5. Nginx mengompresi payload JSON (`Gzip/Brotli`, `< 50 KB`) dan klien langsung merender kartu/tabel breakdown 4 lokasi.

## 5.3 ISO 45001 Field Condition Update & Photo Evidence Flow

```text
Android Field Tech                 Backend API                    Sharp/Storage        PostgreSQL
       │                                │                               │                   │
       │ 1. Pilih "Good -> Broken"      │                               │                   │
       │ 2. Wajib Kamera/Galeri +       │                               │                   │
       │    Kompresi (<=1280px, 75%)    │                               │                   │
       │ 3. POST /uploads/evidence      │                               │                   │
       ├───────────────────────────────►│ 4. Cek RBAC & Magic Bytes     │                   │
       │                                ├──── Strip EXIF + Save UUID ──►│                   │
       │ 5. 201 { photo_url }           │◄──────────────────────────────┤                   │
       │◄───────────────────────────────┤                               │                   │
       │ 6. POST /stocks/update-cond.   │                               │                   │
       │    {itemId, locId, from:GOOD,  │                               │                   │
       │     to:BROKEN, qty, note,      │                               │                   │
       │     photoUrl, version}         │                               │                   │
       ├───────────────────────────────►│ 7. Validasi RBAC Lokasi &     │                   │
       │                                │    PhotoUrl wajib terisi      │                   │
       │                                ├──── BEGIN ACID TRANSACTION ──────────────────────►│
       │                                │     • Lock/Check version & qty_good >= qty        │
       │                                │     • Update qty_good-=qty, qty_broken+=qty, ver+1│
       │                                │     • Insert stock_logs (before/after + photo_url)│
       │                                │◄─── COMMIT (atau 409 Conflict jika ver beda) ─────┤
       │ 8. 200 OK { updatedStock }     │                               │                   │
       │◄───────────────────────────────┤                               │                   │
```

## 5.4 Two-Stage Inter-Location Stock Transfer Flow

Alur ini menyelesaikan konflik antara kebutuhan mutasi antar lokasi dan aturan **Write Local** tanpa mengurangi keamanan:

```text
             [TAHAP 1: KIRIM]                       [TAHAP 2A: TERIMA]
   Admin Gudang WH-1 (Write Local WH-1)    Petugas Lapangan SITE-PTS (Write Local SITE-PTS)
                     │                                            │
   POST /transfers   │                                            │
   (WH-1 -> SITE-PTS)│                                            │
                     ▼                                            │
   ┌─────────────────────────────────┐                            │
   │ ACID Transaction (TRANSFER_OUT) │                            │
   │ WH-1: qty_good    -= qty        │                            │
   │ WH-1: qty_in_trns += qty        │                            │
   │ Transfer: status = IN_TRANSIT   │                            │
   │ Log: action = TRANSFER_OUT      │                            │
   └─────────────────┬───────────────┘                            │
                     │  (Badge Notifikasi Muncul di SITE-PTS)     │
                     └───────────────────────────────────────────►│
                                                                  │ POST /transfers/:id/receive
                                                                  ▼
                                               ┌─────────────────────────────────────┐
                                               │ ACID Transaction (TRANSFER_IN)      │
                                               │ WH-1:     qty_in_trns -= qty        │
                                               │ SITE-PTS: qty_good    += qty        │
                                               │ Transfer: status = RECEIVED         │
                                               │ Log: action = TRANSFER_IN           │
                                               └─────────────────────────────────────┘

   [TAHAP 2B: TOLAK (oleh SITE-PTS) / BATAL (oleh WH-1)]
   -> ACID Transaction: WH-1 qty_in_trns -= qty; WH-1 qty_good += qty;
      Transfer status = REJECTED / CANCELLED; Log = TRANSFER_REJECT / TRANSFER_CANCEL.
```

## 5.5 ISO 9001 Audit Trail & Safe Compliance Export Flow

1. Pengguna (`SUPER_ADMIN`, `ADMIN_GUDANG`, `VIEWER` Pak Hanif/Vika) memilih filter laporan (lokasi, rentang tanggal, tipe `stock` atau `logs`, format `xlsx` atau `pdf`).
2. Klien memanggil `GET /api/v1/reports/export?...` dengan JWT Bearer Token.
3. Backend mengambil data terfilter dalam mode *streaming/batch*:
   - **Excel (`.xlsx`):** Setiap sel teks melewati fungsi `sanitizeSpreadsheetCell()` untuk menetralkan awalan formula (`=`, `+`, `-`, `@`, `\t`, `\r`) sebelum ditulis oleh `exceljs`.
   - **PDF (`.pdf`):** `pdfkit` menyusun dokumen A4 lengkap dengan kop **PT Hikari Teknologi Indonesia**, nomor kontrol dokumen ISO 9001:2015 / ISO 45001:2018, waktu cetak WIB (`Asia/Jakarta`), nama pencetak, tabel data, dan blok tanda tangan audit.
4. Respons dikirim dengan header `Content-Disposition: attachment` dan disimpan melalui dialog berkas lokal OS (`IF-FS-EXPORT`).

---

# 6. SECURITY ARCHITECTURE (DEFENSE-IN-DEPTH & STRIDE)

## 6.1 Six-Layer Security Architecture

1. **Layer 1 — Network & Edge Protection:** Nginx TLS 1.2/1.3, HSTS, redirect HTTP $\rightarrow$ HTTPS, batas ukuran unggahan `3 MB`, *rate limiting* berlapis (`10/15m` login, `120/m` API), dan isolasi jaringan Docker (`internal: true` mencegah akses publik ke PostgreSQL `:5432` dan API `:3000`).
2. **Layer 2 — Identity & Session Security:** Hashing `Argon2id`/`bcrypt (cost >= 12)`, wajib `must_change_password` pada akun baru/reset, JWT Access berumur pendek (`15m`), *Refresh Token Rotation* + *Reuse Detection*, *Remote Force-Logout* untuk HP proyek yang hilang, serta enkripsi penyimpanan token OS (`Keystore`/`DPAPI`/`libsecret`).
3. **Layer 3 — Location-Based Authorization (RBAC):** Middleware server-side memverifikasi `role` dan kesesuaian `assigned_location_id` pada setiap mutasi, menutup seluruh celah IDOR lintas gudang/site.
4. **Layer 4 — Input, Output & Application Hardening:** Validasi skema ketat Zod (*strip/reject unknown*), query terparameterisasi 100% via Prisma ORM, header keamanan `helmet`, CORS whitelist, dan sanitasi anti *Excel Formula Injection*.
5. **Layer 5 — Media & Privacy Isolation:** Validasi *magic bytes* gambar, penghapusan total metadata **EXIF/GPS** via `sharp`, penamaan acak `UUID v4` di luar direktori eksekusi, akses gambar wajib JWT, redaksi rahasia di log Pino, serta minimalisasi PII (UU PDP).
6. **Layer 6 — Runtime, Backup & Supply Chain:** Kontainer API non-root (`USER node`), DB role *least-privilege* (tanpa `UPDATE`/`DELETE` pada `stock_logs`), backup harian terenkripsi **`AES-256`/GPG**, build Android `--obfuscate` + `allowBackup="false"`, dan gerbang rilis `npm audit` 0 Critical/High CVE.

## 6.2 Threat Model Summary (STRIDE Mitigation Matrix)

| Kategori STRIDE | Skenario Ancaman Spesifik PT HTI | Kontrol Mitigasi Arsitektur | Ref. SRS |
| :--- | :--- | :--- | :--- |
| **Spoofing** | Pencurian sesi atau HP lapangan hilang di Site PTS | *Refresh Token Reuse Detection*, *Remote Force-Logout* (`revoke-sessions`), cek `is_active`, Android Keystore | `SRS-SEC-003`, `011`, `012` |
| **Tampering** | Manipulasi stok gudang lain, saldo negatif, atau penghapusan log audit ISO | RBAC lokasi server-side, *Optimistic Locking* (`409`), DB `CHECK >= 0`, `stock_logs` *append-only* + DB `REVOKE UPDATE/DELETE` | `SRS-CAP-003`, `015`; `SRS-SAF-006`; `SRS-SEC-013` |
| **Repudiation** | Petugas menyangkal pernah mengubah kondisi alat atau mengirim transfer | Setiap mutasi mencatat `user_id`, timestamp UTC, `qty_before`/`qty_after` JSONB, dan `photo_url` bukti fisik | `SRS-CAP-022`, `SRS-SAF-002`, `SRS-SEC-009` |
| **Information Disclosure** | Foto gudang/site bocor ke publik, koordinat GPS di EXIF, kebocoran DB/backup | Foto diakses via proxy JWT, EXIF/GPS di-strip `sharp`, port `5432` internal-only, backup dienkripsi `AES-256`/GPG | `SRS-SEC-005`, `008`, `011`, `013` |
| **Denial of Service** | Brute-force login, unggah file raksasa, disk penuh akibat log | Rate limiter `10/15m` & `120/m`, batas upload `2 MB` (Nginx `3 MB`), rotasi log Docker `20m x 5` | `SRS-SEC-004`, `SRS-QAL-011` |
| **Elevation of Privilege** | `VIEWER` mencoba memanggil endpoint tulis, atau *Excel Formula Injection* menyerang PC manajemen | Middleware RBAC ketat di seluruh route, kontainer non-root, sanitasi karakter `=+-@` pada ekspor Excel | `SRS-CAP-003`, `SRS-SEC-006`, `013`, `014` |

---

# 7. DEPLOYMENT & INFRASTRUCTURE ARCHITECTURE (HYBRID DOCKER)

## 7.1 Dual-Mode Deployment Topology (Cloud VPS vs On-Premise LAN/VPN)

Arsitektur mendukung perpindahan tanpa ubah kode (*zero-code-change portability*) antara dua mode infrastruktur:

```text
  MODE A: CLOUD VPS DEPLOYMENT                   MODE B: ON-PREMISE PT HTI SERVER
  ┌───────────────────────────┐                  ┌───────────────────────────┐
  │ WH-1 / WH-2 / Site PTS /  │                  │ WH-1 & WH-2 (LAN Kantor)  │
  │ Site Non PTS (4G / Wi-Fi) │                  │ Site PTS / Non PTS (VPN)  │
  └─────────────┬─────────────┘                  └─────────────┬─────────────┘
                │ https://inv.hti.co.id                        │ https://192.168.1.50
                │ (Let's Encrypt TLS)                          │ (Internal CA TLS)
                ▼                                              ▼
  ┌──────────────────────────────────────────────────────────────────────────┐
  │   IDENTICAL DOCKER COMPOSE STACK (docker-compose.yml + .env)             │
  │   [nginx] ──► [api (node:20, non-root)] ──► [postgres:16] + [volumes]    │
  └──────────────────────────────────────────────────────────────────────────┘
```

Pengguna Desktop dan Android cukup menyesuaikan **Server Base URL** di dialog pengaturan halaman Login + tombol **Uji Koneksi** (`GET /api/v1/health`).

## 7.2 Docker Network Isolation & Volume Strategy

| Sumber Daya Docker | Nama | Konfigurasi Keamanan & Ketahanan |
| :--- | :--- | :--- |
| **Public Edge Network** | `hti_edge_net` | Hanya kontainer `nginx` yang mengikat port host `80:80` dan `443:443`. |
| **Private Backend Network** | `hti_internal_net` | Ditetapkan `internal: true`. Menghubungkan `nginx`, `api`, `postgres`, dan `backup`. Port `5432` & `3000` tidak pernah dibuka ke host/publik. |
| **Database Volume** | `hti_pg_data` | Mount ke `/var/lib/postgresql/data`; didukung PostgreSQL WAL untuk jaminan durabilitas ACID. |
| **Media Volume** | `hti_evidence_data` | Mount ke `/app/storage/evidence` (hak akses dimiliki UID/GID user `node`). |
| **Backup Volume** | `hti_backup_data` | Menyimpan arsip harian `*.dump.enc` dan `*.tar.gz.enc` (retensi 30 hari + sinkronisasi offsite). |

## 7.3 High Availability, Encrypted Backup & Observability Architecture

* **Availability ($\ge 99.5\%$):** Setiap kontainer memiliki `healthcheck` periodik (`30s`) dan kebijakan `restart: unless-stopped`. Nginx menyediakan respons `503 Maintenance` terkendali saat proses migrasi/upgrade.
* **Backup & DR (`RPO <= 24h`, `RTO <= 2h`):** Cron harian `02:00 WIB` menjalankan `pg_dump -Fc` dan arsip `hti_evidence_data`, mengenkripsi paket dengan `AES-256`/`GPG`, mencatat status keberhasilan, dan memutar arsip $> 30$ hari. Prosedur pemulihan (`restore.sh`) teruji secara berkala.
* **Observability:** Seluruh log API berformat JSON terstruktur (`pino`) dengan `X-Request-Id` untuk pelacakan insiden dari layar klien hingga baris log server; Docker log driver `json-file` dibatasi `max-size: 20m`, `max-file: 5`.

---

# 8. ARCHITECTURE DECISION RECORDS (ADRs)

| ADR ID | Keputusan Arsitektur | Alasan Utama (*Rationale*) | Konsekuensi / Trade-Off |
| :--- | :--- | :--- | :--- |
| **`ADR-001`** | **Single Flutter Codebase** untuk Desktop (Windows/Linux) dan Android | Menjamin konsistensi 100% logika klien, kontrak API, dan keamanan token sambil memangkas separuh biaya pengembangan & pemeliharaan dibanding memisah Electron + React Native. | Memerlukan desain *adaptive layout* disiplin (`DesktopShell` $\ge 900\text{dp}$ vs `MobileShell` $< 900\text{dp}$) dan pengujian di 3 target OS. |
| **`ADR-002`** | **Layered Modular Monolith** (Node.js TS + Express + Prisma) alih-alih Microservices | Transaksi stok + transfer + *audit trail* membutuhkan konsistensi ACID ketat pada skala 50 pengguna / 10.000 item; *modular monolith* memberi latensi rendah, deployment Docker sederhana, dan zero overhead jaringan internal. | Batas modul tetap dijaga tegas lewat folder & service layer sehingga mudah diekstrak bila skala kelak tumbuh ekstrem. |
| **`ADR-003`** | **Two-Stage Transfer (`IN_TRANSIT`)** alih-alih Direct Transfer | Mematuhi aturan **Read Global, Write Local** tanpa memberi izin tulis lintas lokasi pada `ADMIN_GUDANG` atau `PETUGAS_LAPANGAN`, sekaligus mencegah barang "hilang di jalan" saat pengiriman gudang $\leftrightarrow$ site. | Membutuhkan kolom `qty_in_transit`, tabel `stock_transfers`, dan langkah konfirmasi terima oleh penerima. |
| **`ADR-004`** | **Optimistic Locking (`version`)** dalam Transaksi Prisma | Mencegah *race condition* ketika dua pengguna mengubah stok bersamaan tanpa menahan kunci tabel panjang (*pessimistic lock*) yang dapat memicu *deadlock*. | Klien harus menangani HTTP `409 Conflict` secara anggun dengan memuat ulang saldo terbaru. |
| **`ADR-005`** | **Abstraksi `StorageService`** (Local Docker Volume $\rightarrow$ S3/MinIO) + Proxy JWT | Menjaga deployment On-Premise tetap ringan tanpa wajib menjalankan klaster MinIO sejak hari pertama, namun siap bermigrasi ke Cloud Object Storage tanpa ubah kode bisnis. | Pengiriman gambar melalui proses Node.js (*stream*), aman untuk skala PT HTI ($\le 50$ user) berkat ukuran foto terkompresi $\le 400\text{ KB}$. |
| **`ADR-006`** | **PostgreSQL `pg_trgm` GIN Index** alih-alih Elasticsearch | Untuk 531 hingga 10.000 item, indeks GIN trigram bawaan PostgreSQL mampu merespons `< 50 ms` di level DB tanpa menambah beban RAM, sinkronisasi data, dan kompleksitas kontainer search engine terpisah. | Ekstensi `pg_trgm` wajib diaktifkan pada inisialisasi migrasi awal database. |

---

# 9. HLD-TO-SRS ARCHITECTURAL TRACEABILITY

| Komponen / Bagian HLD | Requirement SRS (`HTI-SRS-TEIS-001 v1.1`) yang Dipenuhi |
| :--- | :--- |
| **Bagian 2 & 7 (Container & Hybrid Docker Topology)** | `SRS-ENV-001`–`003`, `SRS-RES-001`–`010`, `SRS-ADP-001`–`003`, `SRS-QAL-007`–`011`, `SRS-QAL-019`, `SRS-SEC-013`, `SRS-PKG-003` |
| **Bagian 3.1 (Backend Modular Monolith)** | `SRS-CAP-001`–`025`, `SRS-EIF-001`–`003`, `SRS-IIF-001`–`002`, `SRS-CON-001`–`003`, `SRS-QAL-001`–`006`, `SRS-QAL-016`–`018` |
| **Bagian 3.2 (Flutter Shared-Core Client)** | `SRS-MOD-001`–`002`, `SRS-EIF-004`–`007`, `SRS-IIF-003`, `SRS-ADP-004`, `SRS-SAF-001`–`005`, `SRS-QAL-013`–`015`, `SRS-PER-001`–`002` |
| **Bagian 4 (High-Level Data Architecture & ERD)** | `SRS-DAT-001`–`006`, `SRS-CAP-022`, `SRS-CAP-025`–`026`, `SRS-SAF-006`, `SRS-QAL-012`, `SRS-CON-004` |
| **Bagian 5 (End-to-End Operational Flows)** | `SRS-CAP-001`–`024`, `SRS-SAF-002`–`005`, `SRS-SEC-011`–`012`, `SRS-SEC-014`, `SRS-OTH-001` |
| **Bagian 6 (Defense-in-Depth & STRIDE Security)** | `SRS-SEC-001`–`015`, `SRS-SAF-006`, `SRS-QAL-008`–`009` |
