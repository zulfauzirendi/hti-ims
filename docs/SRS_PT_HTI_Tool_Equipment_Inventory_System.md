# SOFTWARE REQUIREMENTS SPECIFICATION (SRS)
## PT HTI TOOL & EQUIPMENT INVENTORY SYSTEM (HTI-TEIS)

---

| Atribut Dokumen | Keterangan |
| :--- | :--- |
| **Document Identifier** | `HTI-SRS-TEIS-001` |
| **Standard Reference** | MIL-STD-498 (DI-IPSC-81433) & ISO/IEC 25010:2023 |
| **Version** | `1.1` (Production Specification + Enterprise Security Hardening) |
| **Date** | 22 November 2026 |
| **Classification** | INTERNAL CONFIDENTIAL — PT HIKARI TEKNOLOGI INDONESIA |
| **Prepared For** | Manajemen, Operasional Gudang, Site Lapangan & Tim QA/HSE — **PT Hikari Teknologi Indonesia (PT HTI)** |
| **Prepared By** | Software Engineering & Systems Architecture Team |

---

## LEMBAR PENGESAHAN (APPROVAL SHEET)

| Peran | Nama / Jabatan | Tanda Tangan | Tanggal |
| :--- | :--- | :--- | :--- |
| **Approved (Project Sponsor)** | Manajemen / Direktur PT HTI | __________________________ | ____ / ____ / 2026 |
| **Accepted (Project Manager)** | Software Project Manager | __________________________ | ____ / ____ / 2026 |
| **Accepted (QA & ISO Compliance)** | ISO 9001:2015 & ISO 45001:2018 Representative | __________________________ | ____ / ____ / 2026 |
| **Accepted (Operations Lead)** | Warehouse & Site Operations Lead (Pak Hanif / Vika) | __________________________ | ____ / ____ / 2026 |

---

## RECORD OF CHANGES

| Version | Date | Section / Paragraph | Change Type (`A`/`M`/`D`) | Description | Author |
| :---: | :---: | :--- | :---: | :--- | :--- |
| `1.0` | 22 Nov 2026 | Seluruh Dokumen (`1`–`7`) | `A` | Penyusunan awal dokumen SRS standar MIL-STD-498 berdasarkan spesifikasi bisnis PT HTI dengan kelengkapan penuh *Functional* dan *Non-Functional Requirements* berstandar produksi. | Systems Architecture Team |
| `1.1` | 22 Nov 2026 | `3.3.2`, `3.8`, `3.18`, `4.2`, `5.2`, `6.1` | `A`/`M` | Penambahan 5 kebutuhan *Enterprise Security Hardening* (`SRS-SEC-011`–`015`): Android MASVS & Remote Revoke, EXIF/GPS strip, *first-login password change* & *refresh token reuse detection*, Docker/DB hardening & backup terenkripsi `AES-256`, anti Excel Formula Injection, serta *supply chain / secret hygiene*. | Systems Architecture Team |

---

## TABLE OF CONTENTS

1. **SCOPE**
   - 1.1 Identification
   - 1.2 System Overview
   - 1.3 Document Overview
2. **REFERENCED DOCUMENTS**
   - 2.1 Standards & Regulatory Documents
   - 2.2 Project & Internal Documents
3. **REQUIREMENTS**
   - 3.1 Required States and Modes
   - 3.2 CSCI Capability Requirements
   - 3.3 CSCI External Interface Requirements
   - 3.4 CSCI Internal Interface Requirements
   - 3.5 CSCI Internal Data Requirements
   - 3.6 Adaptation Requirements
   - 3.7 Safety Requirements (ISO 45001:2018 & Hazard Prevention)
   - 3.8 Security and Privacy Requirements (OWASP ASVS L2 / MASVS / UU PDP)
   - 3.9 CSCI Environment Requirements
   - 3.10 Computer Resource Requirements (3.10.1 – 3.10.4)
   - 3.11 Software Quality Factors (ISO/IEC 25010 Non-Functional Requirements)
   - 3.12 Design and Implementation Constraints
   - 3.13 Personnel-Related Requirements & Human Factors
   - 3.14 Training-Related Requirements
   - 3.15 Logistics-Related Requirements
   - 3.16 Other Requirements
   - 3.17 Packaging Requirements
   - 3.18 Precedence and Criticality of Requirements
4. **QUALIFICATION PROVISIONS**
5. **REQUIREMENTS TRACEABILITY**
6. **NOTES**
   - 6.1 Abbreviations and Acronyms
   - 6.2 Glossary & Domain Definitions
7. **APPENDIX A — BASELINE DATA (`Nov 25`) & DATABASE SCHEMA REFERENCE**

---

# 1. SCOPE

## 1.1 Identification

Dokumen *Software Requirements Specification* (SRS) ini menetapkan spesifikasi lengkap kebutuhan fungsional dan non-fungsional untuk sistem **PT HTI Tool & Equipment Inventory System (HTI-TEIS)** rilis versi **1.0.0**. Sistem ini terdiri dari dua *Computer Software Configuration Item* (CSCI) utama dan satu utilitas migrasi pendukung:

| CSCI / Component ID | Nama Komponen | Platform Target | Versi |
| :--- | :--- | :--- | :---: |
| `HTI-TEIS-CSCI-01` | HTI Inventory Backend API & Data Engine | Node.js 20 LTS (TypeScript, Express, Prisma ORM), PostgreSQL 16, Nginx (Docker) | `1.0.0` |
| `HTI-TEIS-CSCI-02` | HTI Inventory Cross-Platform Client App | Flutter (Dart 3.x) — Desktop (Windows 10/11, Linux x64) & Android Mobile (SDK 26+) | `1.0.0` |
| `HTI-TEIS-MIG-01` | Baseline Excel ETL Migration & Verifier Utility | Python 3.11+ (`pandas`, `openpyxl`, `psycopg2`) | `1.0.0` |

## 1.2 System Overview

**PT Hikari Teknologi Indonesia (PT HTI)** adalah perusahaan yang didirikan pada **06 November 2014** (Akte Notaris No. 01, Drs. Mokhammad Husni Thamri, S.H., M.Kn) yang bergerak di sektor **Kontraktor Umum, Penyedia Tenaga Kerja (*Manpower*), Pemasok Bahan Habis Pakai (*Consumables & Materials*), dan Pembuatan Mesin Industri**.

Sebelumnya, pencatatan aset peralatan dan perkakas kerja dikelola secara manual melalui berkas spreadsheet bulanan `2025 NEW ASSET TOOL & EQUIPMENT (2).xlsx` (23 *sheet*). Berdasarkan baseline *sheet* **`Nov 25`**, PT HTI mengelola **531 jenis item spesifik** dalam **9 kategori utama** dengan total volume **12.808 unit** yang tersebar di **4 lokasi operasional**: `Warehouse 1`, `Warehouse 2`, `Site PTS`, dan `Site Non PTS`.

Pencatatan berbasis spreadsheet menimbulkan risiko inkonsistensi saldo stok, keterlambatan pencarian alat lintas lokasi, ketiadaan jejak audit mutasi yang tidak dapat dimanipulasi, serta belum tersedianya verifikasi bukti fisik kondisi alat yang rusak/perlu servis. **HTI-TEIS** dibangun sebagai aplikasi terpadu (Desktop & Android berbasis satu *codebase* Flutter dengan Backend terpusat) untuk:

1. Menyediakan pencarian inventaris lintas lokasi secara instan (`< 500 ms`) dengan tampilan distribusi 4 lokasi secara *real-time*.
2. Menegakkan kontrol akses berbasis lokasi (**Read Global, Write Local**) melalui 4 peran pengguna (`SUPER_ADMIN`, `ADMIN_GUDANG`, `PETUGAS_LAPANGAN`, dan `VIEWER` seperti Pak Hanif dan Vika).
3. Menjamin kepatuhan **ISO 9001:2015** melalui *Audit Trail* (`stock_logs`) bersifat *append-only* lengkap dengan *snapshot* kuantitas sebelum/sesudah, alur mutasi antar lokasi **2 tahap** (`In-Transit` $\rightarrow$ `Received`/`Rejected`), dan ekspor laporan resmi (Excel/PDF).
4. Menjamin kepatuhan **ISO 45001:2018** melalui pelacakan kondisi keandalan alat (`Good`, `Service`, `Broken`) yang mewajibkan unggah **foto bukti fisik** setiap kali alat ditandai `Service` atau `Broken`.
5. Mendukung fleksibilitas infrastruktur **Hybrid / Docker-Ready** agar dapat dioperasikan baik di **Server Lokal (On-Premise LAN/VPN PT HTI)** maupun **Cloud VPS**.

## 1.3 Document Overview

Dokumen ini disusun mengikuti standar **MIL-STD-498 (DI-IPSC-81433)** untuk menetapkan kontrak spesifikasi teknis yang objektif, terukur, dan dapat diverifikasi antara manajemen PT HTI, tim pengembang, dan tim *Quality Assurance* (QA).

* **Bagian 1 & 2** menjelaskan ruang lingkup, konteks bisnis PT HTI, dan dokumen acuan.
* **Bagian 3 (`3.1`–`3.18`)** menetapkan seluruh kebutuhan fungsional (`CSCI Capability`) serta kebutuhan non-fungsional secara komprehensif (keamanan, keselamatan K3, performa, reliabilitas, ketersediaan, observabilitas, pemeliharaan, ergonomi/UX, logistik, dan pemaketan) agar sistem layak menyandang standar aplikasi produksi (*enterprise-grade / proper application*).
* **Bagian 4 & 5** menyajikan metode kualifikasi/verifikasi dan matriks keterlacakan dua arah (*Bidirectional Traceability Matrix*).
* **Bagian 6 & 7** berisi glosarium, akronim, dan Lampiran A (matriks baseline data `Nov 25` & ringkasan DDL).

**Keamanan Dokumen:** Dokumen ini bersifat **Internal Confidential** milik PT Hikari Teknologi Indonesia dan tidak boleh didistribusikan keluar tanpa persetujuan tertulis dari manajemen PT HTI.

---

# 2. REFERENCED DOCUMENTS

## 2.1 Standards & Regulatory Documents

| No. | Kode Dokumen | Judul & Edisi | Keterangan Relevansi |
| :---: | :--- | :--- | :--- |
| (a) | `MIL-STD-498` | *Software Development and Documentation — DID DI-IPSC-81433 (SRS)*, 5 December 1994 | Struktur baku penyusunan dokumen SRS. |
| (b) | `ISO 9001:2015` | *Quality Management Systems — Requirements* (Klausul 7.1.5, 7.5, 8.5.2) | Persyaratan ketertelusuran aset, informasi terdokumentasi, dan *Audit Trail*. |
| (c) | `ISO 45001:2018` | *Occupational Health and Safety Management Systems — Requirements* (Klausul 6.1.2, 8.1) | Persyaratan identifikasi bahaya peralatan kerja dan verifikasi kelayakan alat K3. |
| (d) | `ISO/IEC 25010:2023` | *Systems and Software Quality Requirements and Evaluation (SQuaRE)* | Standar rujukan kualitas perangkat lunak (*Non-Functional Requirements*). |
| (e) | `OWASP ASVS v4.0.3` | *Application Security Verification Standard (Level 2)* | Standar keamanan API Backend, autentikasi, otorisasi, dan penanganan input/file. |
| (f) | `OWASP MASVS v2.0` | *Mobile Application Security Verification Standard* | Standar keamanan penyimpanan sesi, jaringan, dan privasi aplikasi Android. |
| (g) | `UU No. 27 Tahun 2022` | *Undang-Undang Pelindungan Data Pribadi (UU PDP) Republik Indonesia* | Kepatuhan pengelolaan data pribadi akun pengguna dan log aktivitas personel. |

## 2.2 Project & Internal Documents

| No. | Nama Dokumen / Berkas | Versi / Tanggal | Keterangan |
| :---: | :--- | :--- | :--- |
| (a) | `HLD_PT_HTI_Tool_Equipment_Inventory_System.md` & `LLD_PT_HTI_Tool_Equipment_Inventory_System.md` | Version 1.0 (22 Nov 2026) | Desain arsitektur makro (C4, ERD, STRIDE) dan desain rinci (Prisma DDL, kontrak API, algoritma) HTI-TEIS. |
| (b) | `2025 NEW ASSET TOOL & EQUIPMENT (2).xlsx` | Sheet `Nov 25` | Register aset eksisting PT HTI (baseline 531 item, 12.808 unit). |
| (c) | Akte Notaris Pendirian PT HTI No. 01 | 06 November 2014 | Legalitas entitas PT Hikari Teknologi Indonesia (Notaris Drs. Mokhammad Husni Thamri, S.H., M.Kn). |
| (d) | `MIL_Std_SRS_Template.doc` | Version 1.1 (12 June 1997) | Template acuan format MIL-STD-498 SEPO. |

---

# 3. REQUIREMENTS

Setiap kebutuhan dalam Bagian 3 diberi pengenal unik proyek (`SRS-<KATEGORI>-<NNN>`), dirumuskan secara objektif dan terukur, serta dikaitkan dengan metode verifikasi di **Bagian 4** dan keterlacakan di **Bagian 5**.

## 3.1 Required States and Modes

CSCI HTI-TEIS wajib mendukung **5 mode operasional** yang terdefinisi secara eksplisit:

| ID | State / Mode | Deskripsi Operasional & Perilaku Sistem Wajib |
| :--- | :--- | :--- |
| `SRS-MOD-001` | **NORMAL_ONLINE** | Mode operasi standar. Seluruh fitur baca (*Global Read*), mutasi lokal (*Local Write*), transfer 2 tahap, unggah foto bukti, dan ekspor laporan beroperasi penuh pada Desktop dan Android. |
| `SRS-MOD-002` | **DEGRADED_CONNECTIVITY** | Mode saat perangkat Android/Desktop mengalami jaringan lambat/terputus. Sistem **dilarang** *crash* atau menghapus data formulir/foto bukti yang sedang diisi pengguna; sistem menampilkan banner status koneksi yang jelas serta tombol **Coba Lagi (*Retry*)** saat koneksi pulih. |
| `SRS-MOD-003` | **MAINTENANCE_MODE** | Mode pemeliharaan terencana (migrasi skema DB/upgrade versi). Backend mengembalikan HTTP `503 Service Unavailable` disertai header `Retry-After` dan pesan ramah pada klien; seluruh mutasi tulis dihentikan sementara guna menjaga integritas data. |
| `SRS-MOD-004` | **INITIAL_MIGRATION_MODE** | Mode eksekusi utilitas ETL (`HTI-TEIS-MIG-01`) satu kali sebelum *go-live*. Akses API publik ditutup hingga skrip migrasi menyelesaikan rekonsiliasi 100% terhadap baseline `Nov 25` (`531` item, `12.808` unit). |
| `SRS-MOD-005` | **EMERGENCY_RECOVERY_MODE** | Mode pemulihan bencana (*disaster recovery*). Operator dapat memulihkan snapshot PostgreSQL dan volume `evidence_storage` melalui prosedur Docker Compose terstandar dalam batas RTO $\le 2\text{ jam}$. |

**Tabel Korelasi Mode terhadap Kelompok Kebutuhan (`SRS-MOD-006`):**
* `NORMAL_ONLINE`: Semua kebutuhan `3.2`–`3.17` aktif penuh.
* `DEGRADED_CONNECTIVITY`: Berlaku `3.3` (timeout/retry), `3.7` (cegah duplikasi submit), `3.11` (fault tolerance & UX error handling).
* `MAINTENANCE_MODE`: Berlaku `3.3` (`/api/v1/health` melaporkan status `maintenance`), `3.8` (akses admin terbatas).
* `INITIAL_MIGRATION_MODE`: Berlaku `3.2.7` (migrasi & assertion), `3.5` (constraint integritas DB).
* `EMERGENCY_RECOVERY_MODE`: Berlaku `3.11` (RPO/RTO backup restore), `3.15` (prosedur operasional logistik).

---

## 3.2 CSCI Capability Requirements

### 3.2.1 Authentication, Session Management & Location-Based RBAC

* **`SRS-CAP-001` (Autentikasi Kredensial):** Sistem wajib mengautentikasi pengguna melalui `POST /api/v1/auth/login` menggunakan `username` dan `password` terhadap hash kata sandi pada tabel `users`, serta menolak pengguna dengan status `is_active = FALSE` menggunakan HTTP `403 Forbidden`.
* **`SRS-CAP-002` (Manajemen Token & Sesi Multi-Perangkat):** Sistem wajib menerbitkan *JWT Access Token* (masa berlaku `15 menit`) dan *Refresh Token* (masa berlaku `7 hari`, disimpan ter-hash pada tabel `refresh_tokens` beserta `device_info`). Pembaruan token melalui `POST /api/v1/auth/refresh` wajib menerapkan *refresh token rotation* dan pencabutan sesi instan saat `POST /api/v1/auth/logout`.
* **`SRS-CAP-003` (Penegakan RBAC — Read Global, Write Local):** Backend middleware wajib menegakkan matriks hak akses berikut pada setiap *request* secara *server-side*:

| Role | Assigned Location | Global Read | Local Write (Status/Remarks) | Kirim Transfer | Terima/Tolak Transfer | Stock In | Disposal & Master/User CRUD |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| `SUPER_ADMIN` | `NULL` (Semua) | Ya | Semua Lokasi | Semua | Semua | Semua | Ya |
| `ADMIN_GUDANG` | `WH-1` / `WH-2` | Ya | Gudang Sendiri | Dari Gudang Sendiri | Ke Gudang Sendiri | Gudang Sendiri | Tidak (`403`) |
| `PETUGAS_LAPANGAN` | `SITE-PTS` / `SITE-NON-PTS` | Ya | Site Sendiri | Dari Site Sendiri | Ke Site Sendiri | Tidak (`403`) | Tidak (`403`) |
| `VIEWER` *(Pak Hanif, Vika)* | `NULL` (Semua) | Ya | Tidak (`403`) | Tidak (`403`) | Tidak (`403`) | Tidak (`403`) | Tidak (`403`) |

* **`SRS-CAP-004` (Profil Pengguna Aktif):** Endpoint `GET /api/v1/auth/me` wajib mengembalikan profil pengguna aktif, peran (`role`), dan objek `assigned_location` agar klien (Desktop & Android) dapat menyesuaikan visibilitas tombol aksi secara dinamis.
* **`SRS-CAP-005` (Penanganan Sesi Kedaluwarsa Otomatis):** Klien Flutter (`dio` interceptor) wajib secara transparan memperbarui *Access Token* ketika menerima HTTP `401 Unauthorized` menggunakan *Refresh Token*; bila *Refresh Token* juga kedaluwarsa/dicabut, klien wajib menghapus kredensial lokal dan mengarahkan pengguna ke halaman Login dengan pesan informatif.

### 3.2.2 Instant Multi-Location Search & Inventory Discovery

* **`SRS-CAP-006` (Pencarian Instan Multi-Kriteria):** Endpoint `GET /api/v1/items/search` wajib mendukung pencarian teks parsial & *case-insensitive* (`pg_trgm`) terhadap `item_code`, `description`, dan `specification`, dikombinasikan dengan filter `category_id`, `location_id`, dan `condition` (`GOOD`, `SERVICE`, `BROKEN`, `IN_TRANSIT`).
* **`SRS-CAP-007` (Debounce & Paginasi):** Antarmuka pencarian Desktop dan Android wajib menerapkan *debounce* `300 ms` untuk mencegah banjir permintaan API. Respons pencarian wajib terpaginasi (`page`, `limit` default `20`, maks `100`) disertai metadata `total` dan `total_pages`.
* **`SRS-CAP-008` (Matriks Breakdown 4 Lokasi):** Setiap baris hasil pencarian dan halaman detail (`GET /api/v1/items/:id`) wajib menampilkan distribusi saldo stok pada seluruh 4 lokasi operasional (`Warehouse 1`, `Warehouse 2`, `Site PTS`, `Site Non PTS`) secara berdampingan mencakup kuantitas `Good`, `Service`, `Broken`, `In-Transit`, `job_code`, dan `remarks`.
* **`SRS-CAP-009` (Filter Item Aktif):** Pencarian standar wajib mengecualikan item yang berstatus *soft-deleted* (`is_active = FALSE`), namun riwayat historisnya tetap dapat dilihat di modul *Audit Trail*.

### 3.2.3 Real-Time Stock Balance, Condition Tracking & ISO 45001 Photo Evidence

* **`SRS-CAP-010` (Perubahan Kondisi Alat):** Endpoint `POST /api/v1/stocks/update-condition` wajib memungkinkan pemindahan kuantitas antar status kondisi (`GOOD` $\leftrightarrow$ `SERVICE` $\leftrightarrow$ `BROKEN`) pada satu lokasi secara atomik dengan memvalidasi bahwa saldo status asal $\ge$ kuantitas yang dipindahkan.
* **`SRS-CAP-011` (Kewajiban Bukti Foto K3 — ISO 45001):** Untuk setiap transisi menuju status `SERVICE` atau `BROKEN` (`GOOD_TO_SERVICE`, `GOOD_TO_BROKEN`, `SERVICE_TO_BROKEN`), sistem wajib menolak permintaan dengan HTTP `400 Bad Request` apabila `note` (minimal 5 karakter) atau `photo_url` (hasil unggah valid via `/api/v1/uploads/evidence`) tidak disertakan.
* **`SRS-CAP-012` (Pembaruan Job Code & Remarks):** Endpoint `PATCH /api/v1/stocks/remarks` wajib memungkinkan pembaruan `job_code` (kode proyek lapangan) dan `remarks` pada lokasi yang menjadi wewenang pengguna serta mencatatnya dalam `stock_logs` (`REMARKS_UPDATE`).
* **`SRS-CAP-013` (Pengadaan / Stock In):** Endpoint `POST /api/v1/stocks/in` (khusus `SUPER_ADMIN` dan `ADMIN_GUDANG` pada gudangnya) wajib menambah saldo `qty_good` beserta catatan referensi pengadaan dan mencatat log `STOCK_IN`.
* **`SRS-CAP-014` (Penghapusan Aset Rusak / Disposal):** Endpoint `POST /api/v1/stocks/dispose` (khusus `SUPER_ADMIN`) wajib hanya dapat mengurangi saldo dari kolom `qty_broken` (mencegah penghapusan langsung barang `GOOD`) disertai alasan tertulis wajib dan pencatatan log `DISPOSAL`.
* **`SRS-CAP-015` (Kontrol Konkurensi & Anti Saldo Negatif):** Seluruh operasi mutasi stok wajib dieksekusi di dalam transaksi ACID (`prisma.$transaction`) dengan pemeriksaan `version` (*optimistic locking*). Jika terjadi bentrokan pembaruan bersamaan, sistem wajib mengembalikan HTTP `409 Conflict` tanpa mengubah saldo, dan klien menampilkan notifikasi pembaruan data terbaru.

### 3.2.4 Two-Stage Inter-Location Stock Transfer Workflow

* **`SRS-CAP-016` (Tahap 1 — Kirim Transfer / `TRANSFER_OUT`):** Endpoint `POST /api/v1/transfers` wajib membuat transaksi transfer dengan nomor unik `TRF-YYYYMMDD-XXXX`, memvalidasi `from_location_id <> to_location_id` dan saldo mencukupi, mengurangi `qty_<condition>` di lokasi asal, menambah `qty_in_transit` di lokasi asal sebesar `qty`, membuat record `stock_transfers` berstatus `IN_TRANSIT`, dan mencatat log `TRANSFER_OUT` dalam satu transaksi atomik.
* **`SRS-CAP-017` (Tahap 2A — Terima Transfer / `TRANSFER_IN`):** Endpoint `POST /api/v1/transfers/:id/receive` (hanya oleh `SUPER_ADMIN` atau pengguna berwenang pada `to_location_id`) wajib memvalidasi status masih `IN_TRANSIT`, mengurangi `qty_in_transit` lokasi asal, menambah `qty_<condition>` pada lokasi tujuan (membuat baris `item_stocks` otomatis jika belum ada), memperbarui status transfer menjadi `RECEIVED` beserta `received_by` & `resolved_at`, dan mencatat log `TRANSFER_IN`.
* **`SRS-CAP-018` (Tahap 2B — Tolak atau Batal Transfer):**
  * `POST /api/v1/transfers/:id/reject` (oleh lokasi tujuan / `SUPER_ADMIN`, wajib disertai `receiver_note`): mengembalikan `qty_in_transit` ke `qty_<condition>` lokasi asal, status menjadi `REJECTED`, mencatat log `TRANSFER_REJECT`.
  * `POST /api/v1/transfers/:id/cancel` (oleh pengirim / `SUPER_ADMIN` selama masih `IN_TRANSIT`): mengembalikan `qty_in_transit` ke `qty_<condition>` lokasi asal, status menjadi `CANCELLED`, mencatat log `TRANSFER_CANCEL`.
* **`SRS-CAP-019` (Daftar & Notifikasi Transfer Tertunda):** Endpoint `GET /api/v1/transfers` wajib mendukung filter `direction=incoming|outgoing` dan `status`, serta menyuplai jumlah transfer masuk berstatus `IN_TRANSIT` sebagai *badge* notifikasi pada Dashboard Desktop dan navigasi Android.

### 3.2.5 Executive Dashboard & Real-Time Stock Aggregator

* **`SRS-CAP-020` (Ringkasan Agregasi 4 Lokasi):** Endpoint `GET /api/v1/dashboard/summary` wajib menghitung agregasi *real-time* jumlah unit `Good`, `Service`, `Broken`, `In-Transit`, dan total volume untuk masing-masing lokasi operasional serta total keseluruhan perusahaan, berikut jumlah transfer masuk tertunda untuk pengguna aktif.
* **`SRS-CAP-021` (Distribusi Kategori & Indikator Kesehatan Aset):** Dashboard Desktop wajib menampilkan persentase kesehatan alat (`% Good` vs `% Service` vs `% Broken`) dan ringkasan volume per 9 kategori utama agar manajemen (termasuk `VIEWER` Pak Hanif & Vika) dapat memantau kondisi aset secara cepat.

### 3.2.6 ISO 9001 Audit Trail & Compliance Report Export

* **`SRS-CAP-022` (Pencatatan Audit Trail Lengkap & Imutabel):** Setiap perubahan kuantitas, kondisi, lokasi, maupun *remarks* wajib secara otomatis menghasilkan entri baru pada `stock_logs` berisi `item_id`, `from_location_id`, `to_location_id`, `action_type`, `status_changed`, `qty_changed`, *snapshot* JSON `qty_before` & `qty_after`, `job_code`, `note`, `photo_url`, `transfer_id`, `user_id`, dan `created_at`. Tidak ada operasi `UPDATE` atau `DELETE` terhadap `stock_logs`.
* **`SRS-CAP-023` (Penampil Audit Trail & Pratinjau Foto):** Endpoint `GET /api/v1/logs` dan antarmuka *Audit Trail Viewer* (Desktop) wajib mendukung filter berdasarkan rentang tanggal (`date_from`, `date_to`), lokasi, item, jenis aksi (`action_type`), dan pengguna, serta menyediakan pratinjau pembesaran (*lightbox*) untuk foto bukti K3 yang terlampir.
* **`SRS-CAP-024` (Ekspor Laporan Kepatuhan Excel & PDF):** Endpoint `GET /api/v1/reports/export` wajib mendukung ekspor:
  * **Laporan Stok Inventaris** (`type=stock`, format `.xlsx` dan `.pdf`): menampilkan seluruh item, kode SKU, kategori, spesifikasi, satuan, dan breakdown stok 4 lokasi sesuai filter aktif.
  * **Laporan Audit Trail ISO 9001** (`type=logs`, format `.xlsx` dan `.pdf`): menampilkan kronologi mutasi sesuai filter tanggal/lokasi.
  * Dokumen PDF wajib menyertakan kop resmi **PT Hikari Teknologi Indonesia**, nomor kontrol dokumen ISO 9001:2015 / ISO 45001:2018, waktu cetak (WIB), nama pencetak, dan kolom tanda tangan verifikasi.

### 3.2.7 Master Data Management & Baseline Excel Migration

* **`SRS-CAP-025` (CRUD Master Data & Soft Delete):** `SUPER_ADMIN` wajib dapat mengelola master Kategori, Lokasi, Pengguna (termasuk reset kata sandi & nonaktifkan akun), serta Master Item. Pembuatan Item otomatis menghasilkan `item_code` unik (`HTI-<KODE_KATEGORI>-<4_DIGIT_SEQ>`). Penghapusan Item wajib berupa *soft delete* (`is_active = FALSE`, `deleted_at = NOW()`) dan dilarang apabila item masih memiliki stok `> 0` atau transfer `IN_TRANSIT`.
* **`SRS-CAP-026` (Migrasi Baseline Excel `Nov 25` & Rekonsiliasi Otomatis):** Utilitas `HTI-TEIS-MIG-01` wajib mem-parsing *sheet* `Nov 25` dari `2025 NEW ASSET TOOL & EQUIPMENT (2).xlsx`, menstandarkan satuan ke huruf kapital (`UNIT`, `PCS`, `SET`, `ROLL`, `EA`, `PAIR`, `BOX`, `BTL`), memetakan 9 kategori dan 4 kode lokasi (`WH-1`, `WH-2`, `SITE-PTS`, `SITE-NON-PTS`), mengisi `items`, `item_stocks`, dan log awal `INITIAL_IMPORT`, serta menjalankan *automated assertion* yang hanya dinyatakan **PASS** jika hasil DB tepat **9 kategori, 4 lokasi, 531 item, 10.340 Good, 119 Service, 2.349 Broken, dan 12.808 total unit**.

---

## 3.3 CSCI External Interface Requirements

### 3.3.1 Interface Identification and Context Diagram

```text
  ┌─────────────────────────┐          ┌─────────────────────────┐
  │  Desktop Users (Admin/  │          │  Field Technicians      │
  │  Gudang / Viewer)       │          │  (Site PTS / Non PTS)   │
  └───────────┬─────────────┘          └───────────┬─────────────┘
              │ IF-UI-DESKTOP                      │ IF-UI-ANDROID
              ▼                                    ▼
  ┌─────────────────────────┐          ┌─────────────────────────┐
  │ Flutter Desktop App     │          │ Flutter Android App     │
  │ (Windows / Linux)       │          │ (Min SDK 26)            │
  │  ├─ IF-FS-EXPORT (.xlsx │          │  └─ IF-HW-CAMERA        │
  │  │  / .pdf Save Dialog) │          │     (Camera / Gallery)  │
  └───────────┬─────────────┘          └───────────┬─────────────┘
              │                                    │
              └──────────────────┬─────────────────┘
                                 │ IF-API-REST (HTTPS JSON + Multipart)
                                 ▼
  ┌──────────────────────────────────────────────────────────────┐
  │  Nginx Reverse Proxy (TLS) ──► Node.js Backend API (/api/v1) │
  └──────────────────────────────┬───────────────────────────────┘
                                 │
              ┌──────────────────┴──────────────────┐
              ▼                                     ▼
  ┌───────────────────────┐             ┌───────────────────────┐
  │ PostgreSQL 16 DB      │◄────────────┤ Python ETL Migrator   │
  │                       │  IF-MIG-DB  │  ▲ IF-MIG-EXCEL       │
  └───────────────────────┘             │  │ (.xlsx Nov 25)     │
                                        └──┴────────────────────┘
```

| Interface ID | Entitas Terhubung | Tipe Antarmuka | Sifat Entitas Eksternal |
| :--- | :--- | :--- | :--- |
| `IF-UI-DESKTOP` | Pengguna Desktop $\leftrightarrow$ `HTI-TEIS-CSCI-02` (Desktop) | GUI Desktop (Windows/Linux) | Dikembangkan (baru) |
| `IF-UI-ANDROID` | Petugas Lapangan $\leftrightarrow$ `HTI-TEIS-CSCI-02` (Android) | GUI Mobile Layar Sentuh | Dikembangkan (baru) |
| `IF-API-REST` | `HTI-TEIS-CSCI-02` $\leftrightarrow$ `HTI-TEIS-CSCI-01` | HTTPS REST/JSON & Multipart Upload | Dikembangkan (kontrak terkunci) |
| `IF-HW-CAMERA` | `HTI-TEIS-CSCI-02` (Android) $\leftrightarrow$ Android OS Camera/Gallery | OS Platform Intent (`image_picker`) | Tetap (Android OS API 26+) |
| `IF-FS-EXPORT` | `HTI-TEIS-CSCI-02` $\leftrightarrow$ Sistem Berkas Lokal OS | File Save/Share Dialog | Tetap (Windows/Linux/Android FS) |
| `IF-MIG-EXCEL` | `HTI-TEIS-MIG-01` $\leftrightarrow$ File Excel `Nov 25` | Pembacaan File `.xlsx` | Tetap (Format Eksisting PT HTI) |

### 3.3.2 Interface Requirements (`IF-API-REST`, `IF-UI-DESKTOP`, `IF-UI-ANDROID`, `IF-HW-CAMERA`)

* **`SRS-EIF-001` (Kontrak Envelope API Standar — `IF-API-REST`):** Seluruh respons JSON dari `/api/v1/*` wajib mengikuti format konsisten:
  * Sukses: `{ "success": true, "data": <object|array>, "meta": { "page": 1, "limit": 20, "total": 531, "requestId": "<uuid>" } }`
  * Error: `{ "success": false, "error": { "code": "<MACHINE_CODE>", "message": "<Pesan Jelas Bahasa Indonesia>", "details": [...] }, "meta": { "requestId": "<uuid>" } }`
* **`SRS-EIF-002` (Kode Status HTTP Semantik):** API wajib menggunakan kode status standar: `200 OK`, `201 Created`, `400 Bad Request` (validasi bisnis), `401 Unauthorized` (token tidak valid/kedaluwarsa), `403 Forbidden` (pelanggaran RBAC lokasi), `404 Not Found`, `409 Conflict` (konflik versi *optimistic locking* atau duplikat SKU/username), `413 Payload Too Large` (foto `> 2 MB`), `422 Unprocessable Entity` (schema Zod gagal), `429 Too Many Requests` (rate limit), `500 Internal Server Error`, dan `503 Service Unavailable`.
* **`SRS-EIF-003` (Kelengkapan Endpoint `/api/v1`):** Backend wajib menyediakan seluruh endpoint yang ditetapkan dalam kontrak:
  * System: `GET /health`
  * Auth: `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `POST /auth/change-password`, `GET /auth/me`
  * Dashboard: `GET /dashboard/summary`
  * Items: `GET /items/search`, `GET /items/:id`, `POST /items`, `PATCH /items/:id`, `DELETE /items/:id`
  * Stocks: `POST /stocks/update-condition`, `PATCH /stocks/remarks`, `POST /stocks/in`, `POST /stocks/dispose`
  * Transfers: `POST /transfers`, `GET /transfers`, `POST /transfers/:id/receive`, `POST /transfers/:id/reject`, `POST /transfers/:id/cancel`
  * Media: `POST /uploads/evidence`, `GET /uploads/evidence/:filename`
  * Logs & Reports: `GET /logs`, `GET /reports/export`
  * Master & Users: `GET/POST/PATCH /categories`, `GET/POST/PATCH /locations`, `GET/POST/PATCH /users`, `POST /users/:id/revoke-sessions`
* **`SRS-EIF-004` (Antarmuka Desktop — `IF-UI-DESKTOP`):** Aplikasi Desktop wajib menerapkan tata letak *navigation rail/sidebar* adaptif untuk lebar layar $\ge 900\text{ dp}$, mendukung resolusi minimal `1366 x 768` tanpa *horizontal overflow*, menyajikan tabel data dengan pengurutan kolom, modal aksi cepat, serta dialog simpan file lokal (`IF-FS-EXPORT`) untuk hasil unduhan Excel/PDF.
* **`SRS-EIF-005` (Antarmuka Android — `IF-UI-ANDROID`):** Aplikasi Android wajib menerapkan tata letak *bottom navigation bar* (`Cari & Stok`, `Transfer Masuk`, `Profil/Pengaturan`), orientasi *portrait* optimal untuk operasi satu tangan di lapangan, tombol aksi cepat *update* kondisi, serta indikator visual status warna + ikon + label teks.
* **`SRS-EIF-006` (Antarmuka Kamera & Kompresi — `IF-HW-CAMERA`):** Saat pengguna Android memilih unggah bukti foto K3, aplikasi wajib meminta izin kamera/media secara *runtime* sesuai standar Android SDK 26–35, mengompresi gambar di sisi klien ke resolusi maksimal `1280 px` (sisi terpanjang) dengan kualitas `75%` (target ukuran `< 400 KB`, batas keras `<= 2 MB`), serta menampilkan pratinjau sebelum unggah.
* **`SRS-EIF-007` (Pengaturan & Uji Koneksi Server):** Halaman Login pada Desktop dan Android wajib menyediakan dialog konfigurasi **Server Base URL** beserta tombol **Uji Koneksi** yang memanggil `GET /api/v1/health` dan melaporkan latensi serta status keterhubungan server dalam `< 5 detik`.

---

## 3.4 CSCI Internal Interface Requirements

* **`SRS-IIF-001` (Arsitektur Berlapis Backend):** `HTI-TEIS-CSCI-01` wajib memisahkan tanggung jawab internal ke dalam lapisan ketat: `Routes` $\rightarrow$ `Validation (Zod)` $\rightarrow$ `Auth/RBAC Middleware` $\rightarrow$ `Domain Services` $\rightarrow$ `Prisma Data Access Layer`. Logika bisnis dan transaksi stok dilarang diletakkan langsung di lapisan *controller/route*.
* **`SRS-IIF-002` (Abstraksi Layanan Penyimpanan Media):** Akses baca/tulis file foto bukti K3 di backend wajib melalui antarmuka `StorageService` (`save()`, `getStream()`, `delete()`) sehingga implementasi awal (*Local Docker Volume*) dapat diganti ke *Object Storage* S3/MinIO tanpa mengubah logika bisnis modul stok maupun API.
* **`SRS-IIF-003` (Pemisahan Core & Adaptive Shell pada Flutter):** `HTI-TEIS-CSCI-02` wajib memisahkan lapisan logika/data bersama (`lib/core/`, `lib/features/*/data/`, `lib/features/*/providers/`) dari lapisan presentasi adaptif (`DesktopShell` vs `MobileShell`) untuk menjamin konsistensi aturan bisnis 100% antara Desktop dan Android.

---

## 3.5 CSCI Internal Data Requirements

* **`SRS-DAT-001` (Skema Relasional PostgreSQL 16):** Sistem wajib mengimplementasikan 8 tabel relasional ternormalisasi (`categories`, `locations`, `items`, `users`, `refresh_tokens`, `item_stocks`, `stock_transfers`, `stock_logs`) sesuai spesifikasi DDL pada **Lampiran A** dan `prisma/schema.prisma`.
* **`SRS-DAT-002` (Integritas Referensial & Domain Constraint):**
  * Seluruh kolom kuantitas (`qty_good`, `qty_service`, `qty_broken`, `qty_in_transit`) wajib memiliki `CHECK (>= 0)` pada tingkat database.
  * Kombinasi `(item_id, location_id)` pada `item_stocks` wajib bersifat `UNIQUE`.
  * Relasi ke `stock_logs` dan `stock_transfers` wajib menggunakan `ON DELETE RESTRICT` pada `items` dan `locations` guna mencegah hilangnya bukti audit ISO 9001.
* **`SRS-DAT-003` (Standarisasi Kode Lokasi & Satuan):** Kode lokasi wajib distandarkan (`WH-1`, `WH-2`, `SITE-PTS`, `SITE-NON-PTS`) dan satuan item wajib uppercase tervalidasi (`UNIT`, `PCS`, `SET`, `ROLL`, `EA`, `PAIR`, `BOX`, `BTL`).
* **`SRS-DAT-004` (Indeks Performa Basis Data):** Database wajib mengaktifkan ekstensi `pg_trgm` serta membentuk indeks GIN trigram pada `items(description)` dan `items(specification)`, serta indeks B-tree pada `items(category_id)`, `item_stocks(location_id)`, `stock_transfers(to_location_id, status)`, `stock_transfers(from_location_id, status)`, `stock_logs(created_at DESC)`, dan `stock_logs(item_id, created_at DESC)`.
* **`SRS-DAT-005` (Standarisasi Zona Waktu):** Seluruh kolom *timestamp* wajib disimpan dalam standar `UTC` (`TIMESTAMPTZ` / ISO 8601) di PostgreSQL dan dikonversi ke **WIB (`Asia/Jakarta`, `UTC+7`)** pada tampilan antarmuka klien serta laporan Excel/PDF.
* **`SRS-DAT-006` (Retensi Data Audit ISO):** Data `stock_logs`, `stock_transfers`, *soft-deleted* `items`, dan file foto bukti K3 (`evidence_storage`) wajib dipertahankan minimal **5 tahun** untuk memenuhi kebutuhan audit eksternal ISO 9001:2015 dan ISO 45001:2018.

---

## 3.6 Adaptation Requirements

* **`SRS-ADP-001` (Portabilitas Endpoint Server Hybrid):** Aplikasi Desktop dan Android wajib menyimpan *Server Base URL* secara lokal (tanpa *hardcoding* alamat IP/domain) agar dapat berpindah antara lingkungan **On-Premise LAN/VPN PT HTI** dan **Cloud VPS** tanpa kompilasi ulang (*rebuild*).
* **`SRS-ADP-002` (Konfigurasi Backend Berbasis Environment):** Seluruh parameter instalasi backend (`PORT`, `DATABASE_URL`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `CORS_ORIGINS`, `UPLOAD_MAX_MB`, `STORAGE_DRIVER`, `LOG_LEVEL`, `TZ`) wajib disuntikkan melalui variabel lingkungan (`.env`) dan divalidasi saat *startup* (sistem wajib gagal mulai secara eksplisit/*fail-fast* jika variabel kritis kosong).
* **`SRS-ADP-003` (Ekstensibilitas Lokasi & Kategori):** Menambah lokasi proyek baru (di luar 4 lokasi awal) atau kategori baru melalui antarmuka `SUPER_ADMIN` wajib langsung terefleksi di pencarian, dashboard, RBAC, dan formulir transfer tanpa perubahan kode atau skema database.
* **`SRS-ADP-004` (Bahasa & Konvensi Istilah):** Antarmuka pengguna, pesan validasi, dan laporan resmi wajib menggunakan **Bahasa Indonesia** yang jelas dengan mempertahankan istilah teknis operasional standar PT HTI (`Good`, `Service`, `Broken`, `In-Transit`, `Job Code`, `Warehouse`, `Site`).

---

## 3.7 Safety Requirements (ISO 45001:2018 & Operational Hazard Prevention)

Meskipun sistem tidak mengendalikan aktuator mekanis secara langsung, keakuratan informasi kelayakan peralatan (`INVENTARIS SAFETY`, `LIFTING AND PULLING TOOLS`, `ELECTRICAL & PNEUMATIC TOOLS`) berdampak langsung pada keselamatan kerja (K3) personel di lapangan.

* **`SRS-SAF-001` (Indikator Visual Bahaya Alat Tidak Layak Pakai):** Peralatan dengan saldo `Broken > 0` atau `Service > 0` wajib ditampilkan dengan lencana peringatan kontras tinggi yang mudah dikenali sekaligus ramah buta warna (kombinasi warna + ikon + label teks: Merah `#D32F2F` + ikon bahaya untuk `Broken`, Oranye `#F57C00` + ikon perbaikan untuk `Service`, Hijau `#2E7D32` + ikon centang untuk `Good`).
* **`SRS-SAF-002` (Blokir Laporan Kerusakan Tanpa Bukti Fisik):** Sistem wajib mencegah perubahan kondisi alat ke `Service` atau `Broken` tanpa bukti foto aktual dan catatan kendala guna memastikan tim HSE/teknisi dapat menilai tingkat bahaya secara akurat (ISO 45001:2018).
* **`SRS-SAF-003` (Peringatan Transfer Alat Rusak/Servis):** Apabila pengguna memilih memindahkan alat dengan kondisi `BROKEN` atau `SERVICE` (misal mengirim alat rusak dari Site ke Warehouse untuk perbaikan), sistem wajib menampilkan dialog konfirmasi berlabel peringatan bahwa barang yang dikirim berstatus **TIDAK LAYAK OPERASI**.
* **`SRS-SAF-004` (Konfirmasi Dua Langkah Aksi Kritis):** Seluruh tindakan berdampak tinggi (`Disposal/Write-Off`, `Soft Delete Item`, `Tolak/Batal Transfer`, `Nonaktifkan Akun`) wajib menampilkan dialog konfirmasi eksplisit yang memuat ringkasan nama item, kode SKU, jumlah unit, dan lokasi terdampak sebelum dieksekusi.
* **`SRS-SAF-005` (Perlindungan Anti-Duplikasi Submit):** Tombol kirim (*Submit*) pada Desktop dan Android wajib dinonaktifkan (*disabled* + indikator *loading*) selama *request* mutasi berjalan, disertai *idempotency protection* pada form transfer/mutasi agar ketukan ganda (*double-tap*) di layar sentuh lapangan tidak menyebabkan pengurangan stok ganda.
* **`SRS-SAF-006` (Kerahasiaan & Imutabilitas Jejak Audit):** Sistem dilarang menyediakan fitur ubah/hapus terhadap tabel `stock_logs` melalui API maupun antarmuka pengguna mana pun (mencegah penghilangan jejak insiden kerusakan alat).

---

## 3.8 Security and Privacy Requirements (OWASP ASVS L2 / MASVS / UU PDP)

* **`SRS-SEC-001` (Hashing Kata Sandi Kuat):** Kata sandi pengguna wajib di-hash menggunakan **`Argon2id`** (direkomendasikan, `memoryCost >= 64 MiB`, `timeCost >= 3`) atau **`bcrypt`** (`cost >= 12`). Penyimpanan kata sandi *plaintext* atau hash lemah (`MD5`/`SHA-1`) dilarang keras.
* **`SRS-SEC-002` (Kebijakan Kompleksitas Kata Sandi):** Kata sandi baru wajib memenuhi panjang minimal `8 karakter` yang memuat kombinasi huruf besar, huruf kecil, dan angka.
* **`SRS-SEC-003` (Keamanan JWT & Penyimpanan Kredensial Klien):**
  * *Secret key* penandatanganan JWT wajib memiliki entropi minimal `256 bit` dan berbeda antara *Access Token* dan *Refresh Token*.
  * Pada klien (Android/Desktop), token sesi wajib disimpan di penyimpanan terenkripsi OS melalui `flutter_secure_storage` (*Android Keystore*, *Windows DPAPI*, *Linux Secret Service/libsecret*), **dilarang** disimpan di `SharedPreferences` polos.
* **`SRS-SEC-004` (Perlindungan Brute-Force & Rate Limiting):** Endpoint `POST /api/v1/auth/login` wajib dibatasi maksimal `10 percobaan per 15 menit per IP/username` (mengembalikan HTTP `429 Too Many Requests`). Endpoint API umum dibatasi maksimal `120 request per menit per pengguna`.
* **`SRS-SEC-005` (Enkripsi Transportasi TLS):** Seluruh komunikasi produksi antara klien (Desktop/Android) dan server wajib menggunakan **HTTPS (TLS 1.2 minimal, disarankan TLS 1.3)** yang diterminasi pada Nginx Reverse Proxy. Trafik HTTP (`port 80`) wajib dialihkan otomatis ke HTTPS (`301`).
* **`SRS-SEC-006` (Pencegahan SQL Injection, XSS & IDOR):**
  * Seluruh kueri basis data wajib terparameterisasi melalui Prisma ORM (dilarang merangkai string SQL mentah dari input pengguna).
  * Seluruh body/query/params wajib divalidasi ketat dengan skema **Zod** (*strict mode* menolak properti tak dikenal).
  * Setiap permintaan mutasi lokasi wajib memverifikasi kepemilikan lokasi pengguna terhadap `req.user.assigned_location_id` di server guna mencegah serangan *Insecure Direct Object Reference* (IDOR).
* **`SRS-SEC-007` (Keamanan HTTP Headers & CORS):** Backend wajib menerapkan `helmet` (termasuk `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Strict-Transport-Security`) dan kebijakan CORS *whitelist* berbasis `.env` (dilarang menggunakan wildcard `*` bersama kredensial).
* **`SRS-SEC-008` (Keamanan Unggah & Akses Foto Bukti):**
  * Unggahan foto wajib divalidasi berdasarkan *magic bytes* file (bukan hanya ekstensi) dan hanya menerima `image/jpeg`, `image/png`, atau `image/webp` dengan ukuran maksimal `2 MB`.
  * Nama file wajib diganti menjadi `UUID v4` acak dan disimpan di luar direktori eksekusi aplikasi (mencegah *path traversal* dan eksekusi skrip).
  * Pengambilan gambar (`GET /api/v1/uploads/evidence/:filename`) wajib memerlukan autentikasi JWT yang valid agar foto internal bengkel/site PT HTI tidak terbuka ke publik.
* **`SRS-SEC-009` (Log Audit Keamanan & Redaksi Data Sensitif):** Sistem wajib mencatat peristiwa keamanan (*login* gagal, pelanggaran RBAC `403`, perubahan role, reset kata sandi, pencabutan sesi) dalam log terstruktur. Seluruh log aplikasi wajib secara otomatis menyamarkan (*redact*) field `password`, `authorization`, `accessToken`, dan `refreshToken`.
* **`SRS-SEC-010` (Kepatuhan Privasi Data — UU PDP):** Sistem wajib menerapkan prinsip minimalisasi data pribadi (hanya menyimpan `username`, `full_name`, `role`, dan `assigned_location_id` untuk operasional kerja) serta melarang akses daftar pengguna oleh peran selain `SUPER_ADMIN`.
* **`SRS-SEC-011` (Android MASVS Hardening, EXIF Strip & Remote Force-Logout):**
  * Build rilis Android wajib mengaktifkan *code obfuscation* (`flutter build apk --release --obfuscate --split-debug-info=...`), menetapkan `android:allowBackup="false"`, dan menonaktifkan *cleartext HTTP* secara default (`android:usesCleartextTraffic="false"`).
  * Seluruh metadata **EXIF/GPS** pada foto bukti K3 wajib dihapus (*stripped*) sebelum disimpan di server (melalui `sharp` di backend dan/atau kompresor klien) demi privasi koordinat lokasi & perangkat personel.
  * `SUPER_ADMIN` wajib memiliki aksi **Force Logout / Revoke All Sessions** (`POST /api/v1/users/:id/revoke-sessions`) guna langsung mencabut seluruh *refresh token* aktif apabila perangkat Android petugas lapangan hilang atau dicuri, didukung pengecekan status `is_active` pada middleware autentikasi.
* **`SRS-SEC-012` (Siklus Hidup Akun & Deteksi Pencurian Refresh Token):**
  * Setiap akun baru atau akun yang kata sandinya direset oleh `SUPER_ADMIN` wajib memiliki flag `must_change_password = TRUE`, sehingga pengguna dipaksa mengganti kata sandi (`POST /api/v1/auth/change-password`) sebelum dapat mengakses endpoint operasional lain. Kredensial *default* lemah dilarang ada pada lingkungan produksi.
  * Sistem wajib menerapkan **Refresh Token Reuse Detection**: apabila *refresh token* yang telah dirotasi/dicabut kembali dikirim ke `/api/v1/auth/refresh`, sistem wajib menganggap terjadi indikasi pencurian token, segera mencabut seluruh sesi aktif pengguna tersebut, dan mencatat insiden tingkat `WARN/ALERT` pada log keamanan.
* **`SRS-SEC-013` (Docker Container, Database Hardening & Enkripsi Backup):**
  * Kontainer API Node.js wajib berjalan sebagai **non-root user** (`USER node`) dengan *read-only root filesystem* (kecuali mount volume `/app/storage/evidence` dan `/tmp`).
  * Port PostgreSQL (`5432`) **dilarang diekspos ke antarmuka jaringan publik** (hanya dapat diakses di dalam internal Docker network oleh layanan API dan utilitas backup lokal).
  * Peran database aplikasi mengikuti prinsip *least privilege* (tanpa hak `SUPERUSER` atau `DROP`/`TRUNCATE` pada tabel audit `stock_logs`).
  * Seluruh arsip backup harian (`pg_dump` dan volume foto bukti) wajib dienkripsi menggunakan **`AES-256` / GPG** sebelum disalin ke penyimpanan *offsite*.
* **`SRS-SEC-014` (Pencegahan Excel / CSV Formula Injection):** Pada proses ekspor laporan Excel (`.xlsx`), setiap nilai teks masukan pengguna (`description`, `specification`, `remarks`, `note`, `job_code`) yang diawali karakter formula (`=`, `+`, `-`, `@`, `Tab`, atau `CR`) wajib disanitasi/di-*escape* sebagai teks literal (*apostrophe prefix* atau tipe string eksplisit) agar tidak mengeksekusi rumus berbahaya saat dibuka di perangkat manajemen.
* **`SRS-SEC-015` (Keamanan Supply Chain & Manajemen Rahasia):**
  * Sebelum rilis produksi, dependensi Backend dan Flutter wajib lolos pemindaian kerentanan (`npm audit --omit=dev`) dengan **0 kerentanan tingkat Critical dan High CVE**.
  * Berkas `.env`, sertifikat TLS privat, dan *Android release signing keystore* (`.jks`) **dilarang** disimpan di dalam repositori kontrol versi (Git/VCS) dan wajib didaftarkan pada `.gitignore`.

---

## 3.9 CSCI Environment Requirements

* **`SRS-ENV-001` (Lingkungan Server Produksi):** Backend & Database wajib dapat berjalan di atas Linux x86_64/ARM64 (Ubuntu 22.04/24.04 LTS, Debian 12, atau RHEL/Rocky Linux) dengan **Docker Engine $\ge 24.0$** dan **Docker Compose v2**, baik pada Cloud VPS maupun Server On-Premise PT HTI.
* **`SRS-ENV-002` (Lingkungan Klien Desktop):** Aplikasi Desktop wajib berjalan secara *native* pada **Windows 10 / Windows 11 (64-bit)** dan **Linux Desktop (64-bit, GTK 3 / Wayland / X11)** tanpa memerlukan instalasi *runtime* tambahan oleh pengguna akhir.
* **`SRS-ENV-003` (Lingkungan Klien Android):** Aplikasi Android wajib berjalan pada perangkat **Android 8.0 Oreo (API Level 26)** hingga **Android 15+ (API Level 35+)** dengan arsitektur `arm64-v8a` dan `armeabi-v7a`, serta tetap terbaca jelas di bawah pencahayaan gudang/lapangan luar ruang.

---

## 3.10 Computer Resource Requirements

### 3.10.1 Computer Hardware Requirements

| Komponen | Spesifikasi Minimum (`SRS-RES-001`) | Spesifikasi Direkomendasikan (`SRS-RES-002`) |
| :--- | :--- | :--- |
| **Server (Docker Host — On-Premise / Cloud VPS)** | 2 vCPU (x86_64), 4 GB RAM, 50 GB SSD, NIC 100 Mbps | 4 vCPU, 8 GB RAM, 100 GB NVMe SSD (+ 50 GB volume backup terpisah), NIC 1 Gbps |
| **PC / Laptop Desktop Client** | Prosesor Dual-Core 2.0 GHz, 4 GB RAM, 500 MB ruang disk, Layar `1366 x 768` | Prosesor Quad-Core, 8 GB RAM, SSD, Layar `1920 x 1080` |
| **Perangkat Android Lapangan** | Quad-Core SoC, 3 GB RAM, 500 MB ruang kosong, Kamera Belakang $\ge 5\text{ MP}$, Layar $\ge 5.5"$ | Octa-Core SoC, 4+ GB RAM, Kamera Autofokus $\ge 12\text{ MP}$, konektivitas 4G LTE / Wi-Fi |

### 3.10.2 Computer Hardware Resource Utilization Requirements

* **`SRS-RES-003` (Utilisasi Server pada Beban Puncak):** Di bawah beban puncak simulasi (**50 pengguna aktif bersamaan**, **10.000 item**, **100.000 baris `stock_logs`**), utilisasi rata-rata CPU server wajib $\le 60\%$ dan utilisasi memori RAM wajib $\le 75\%$ pada spesifikasi minimum.
* **`SRS-RES-004` (Utilisasi Klien Desktop):** Konsumsi RAM aplikasi Desktop wajib $\le 250\text{ MB}$ saat *idle* dan $\le 500\text{ MB}$ saat menampilkan tabel pencarian penuh/ekspor laporan, dengan performa *scrolling* antarmuka $\ge 60\text{ FPS}$.
* **`SRS-RES-005` (Utilisasi & Ukuran Klien Android):** Konsumsi RAM aplikasi Android wajib $\le 200\text{ MB}$ dalam operasi normal, ukuran paket instalasi APK rilis $\le 50\text{ MB}$, dan waktu *cold start* hingga layar Login/Dashboard muncul $\le 3\text{ detik}$ pada perangkat kelas menengah (*mid-range*).
* **`SRS-RES-006` (Efisiensi Penyimpanan Media):** Kompresi foto bukti K3 di klien wajib menekan ukuran file rata-rata menjadi $\le 400\text{ KB}$ per foto (sehingga kapasitas 10.000 foto bukti hanya membutuhkan sekitar $\approx 4\text{ GB}$ ruang penyimpanan).

### 3.10.3 Computer Software Requirements

* **`SRS-RES-007` (Dependensi Perangkat Lunak Terkunci):** Sistem wajib dibangun dan dijalankan menggunakan versi stabil (LTS) berikut:
  * **Client Framework:** Flutter SDK `3.24+` (Dart `3.5+`) dengan paket utama `flutter_riverpod`, `dio`, `go_router`, `flutter_secure_storage`, `image_picker`, `flutter_image_compress`.
  * **Backend Runtime:** Node.js `20 LTS`, TypeScript `5.x`, Express `4.x`, Prisma ORM `5.x`/`6.x`, Zod `3.x`, Multer, Pino (structured logger), `exceljs` (ekspor Excel), `pdfkit` / Puppeteer-free PDF engine (ekspor PDF ringan).
  * **Database & Proxy:** PostgreSQL `16` (`postgres:16-alpine` + `pg_trgm`), Nginx `1.26+` (`nginx:1.26-alpine`).
  * **Migration Utility:** Python `3.11+` (`pandas`, `openpyxl`, `psycopg2-binary`).

### 3.10.4 Computer Communications Requirements

* **`SRS-RES-008` (Topologi Konektivitas 4 Lokasi):** Sistem wajib mendukung akses simultan dari 4 lokasi fisik (`Warehouse 1`, `Warehouse 2`, `Site PTS`, `Site Non PTS`) melalui Internet publik (HTTPS/TLS) apabila di-hosting di Cloud VPS, atau melalui Corporate LAN/VPN apabila di-hosting di Server On-Premise PT HTI.
* **`SRS-RES-009` (Efisiensi Bandwidth & Ketahanan Jaringan Lapangan):**
  * Nginx dan Express wajib mengaktifkan kompresi respons **Gzip/Brotli** sehingga ukuran payload JSON per halaman pencarian (20 item) $\le 50\text{ KB}$.
  * Aplikasi Android wajib tetap operasional dengan baik pada jaringan seluler lapangan 3G/4G berkecepatan rendah ($\ge 512\text{ Kbps}$), dengan batas *timeout* terkonfigurasi (`15 detik` untuk API JSON standar, `45 detik` untuk unggah multipart foto bukti).
* **`SRS-RES-010` (Diagnostik & Health Probe):** Endpoint `GET /api/v1/health` wajib memverifikasi konektivitas aktif ke PostgreSQL (`SELECT 1`) dan keteraksesan tulis/baca volume `evidence_storage`, serta merespons dalam $\le 200\text{ ms}$ untuk keperluan *Docker healthcheck* dan pemantauan *uptime*.

---

## 3.11 Software Quality Factors (ISO/IEC 25010 Non-Functional Requirements)

Bagian ini mendefinisikan standar kualitas terukur agar HTI-TEIS benar-benar memenuhi kriteria aplikasi produksi yang **andal, cepat, aman, mudah dipelihara, dan siap audit (*proper enterprise application*)**.

### A. Performance Efficiency (Performa & Latensi)
* **`SRS-QAL-001` (Latensi Pencarian Instan):** Endpoint `GET /api/v1/items/search` (pada dataset hingga `10.000` item dan `50` pengguna bersamaan) wajib merespons dengan **p95 $\le 300\text{ ms}$** dan **p99 $\le 500\text{ ms}$** (diukur di server API).
* **`SRS-QAL-002` (Latensi Mutasi & Dashboard):** Endpoint mutasi (`POST /stocks/update-condition`, `POST /transfers`, `POST /transfers/:id/receive`) wajib memiliki **p95 $\le 400\text{ ms}$**; `GET /dashboard/summary` wajib memiliki **p95 $\le 500\text{ ms}$**.
* **`SRS-QAL-003` (Kecepatan Ekspor Laporan):** Pembuatan dokumen laporan Excel (`.xlsx`) maupun PDF hingga `5.000` baris data wajib selesai dalam **$\le 5\text{ detik}$**.

### B. Reliability & Fault Tolerance (Reliabilitas & Toleransi Kesalahan)
* **`SRS-QAL-004` (Zero Data Loss & Konsistensi Transaksi):** 100% transaksi stok yang menerima respons HTTP `200`/`201` wajib tersimpan permanen di PostgreSQL (*Write-Ahead Logging* aktif) lengkap dengan entri `stock_logs` yang bersesuaian. Tidak boleh ada kondisi *partial write* (saldo berubah tetapi log gagal tercatat, atau sebaliknya).
* **`SRS-QAL-005` (Penanganan Error Terkendali):** Backend wajib memiliki *global error handler* yang menangkap seluruh pengecualian tak terduga tanpa menjatuhkan proses Node.js, mengembalikan kode kesalahan terstruktur (tanpa membocorkan *stack trace* pada mode produksi). Klien Flutter wajib memiliki *error boundary* yang menampilkan pesan ramah Bahasa Indonesia + tombol *Retry*.
* **`SRS-QAL-006` (Stabilitas Operasi Berkelanjutan):** Backend wajib beroperasi stabil tanpa kebocoran memori (*memory leak*) dengan target **MTBF (Mean Time Between Failures) $\ge 720\text{ jam}$** (30 hari operasi terus-menerus).

### C. Availability, Backup & Disaster Recovery (Ketersediaan & Pemulihan Bencana)
* **`SRS-QAL-007` (Target Ketersediaan / SLA):** Sistem wajib mencapai tingkat ketersediaan (**Availability**) minimal **$\ge 99.5\%$** pada jam operasional PT HTI (Senin–Sabtu, `07:00–19:00 WIB`), setara maksimal `3,6 jam` *unplanned downtime* per bulan.
* **`SRS-QAL-008` (Backup Otomatis — RPO $\le 24\text{ Jam}$):** Sistem wajib dilengkapi skrip backup terjadwal harian (`02:00 WIB`) yang mencadangkan *dump* PostgreSQL terkompresi (`pg_dump -Fc`) dan arsip volume `evidence_storage` dengan retensi bergulir minimal **30 hari** serta dukungan salinan *offsite*.
* **`SRS-QAL-009` (Pemulihan Bencana — RTO $\le 2\text{ Jam}$):** Prosedur pemulihan penuh sistem (database + media bukti foto + layanan API) pada server baru atau eksisting melalui Docker Compose wajib dapat diselesaikan dalam waktu **$\le 2\text{ jam}$** dan diuji minimal setiap 3 bulan.

### D. Observability & Diagnostics (Pemantauan & Pelacakan Insiden)
* **`SRS-QAL-010` (Structured Logging & Correlation ID):** Setiap permintaan HTTP wajib menghasilkan atau meneruskan header `X-Request-Id` (UUID) yang dicatat dalam log JSON terstruktur (`pino`) mencakup timestamp, level, method, path, status code, duration (`ms`), `userId`, dan `requestId`.
* **`SRS-QAL-011` (Rotasi Log & Pemantauan Kontainer):** Kontainer Docker wajib dikonfigurasi dengan batas rotasi log (`max-size: 20m`, `max-file: 5`) guna mencegah disk penuh, serta *healthcheck* otomatis dan kebijakan *restart* (`restart: unless-stopped`).

### E. Scalability & Capacity (Skalabilitas & Kapasitas Pertumbuhan)
* **`SRS-QAL-012` (Kapasitas Pertumbuhan 5 Tahun):** Arsitektur database dan API wajib mampu menampung pertumbuhan minimal hingga **10.000 master item**, **20 lokasi proyek**, **200 akun pengguna**, **1.000.000 baris `stock_logs`**, dan **50.000 foto bukti K3** tanpa perubahan arsitektur maupun degradasi performa di atas batas `SRS-QAL-001`.

### F. Usability & User Experience (Kemudahan Penggunaan)
* **`SRS-QAL-013` (Efisiensi Tugas Lapangan):** Pengguna baru (Petugas Lapangan) setelah pelatihan 30 menit wajib mampu mencari item dan melaporkan perubahan kondisi `Good` $\rightarrow$ `Broken` beserta pengambilan foto bukti dan input `job_code` dalam waktu **$\le 60\text{ detik}$** (maksimal 5 interaksi ketukan).
* **`SRS-QAL-014` (Ergonomi Sentuh & Pintasan Keyboard):**
  * Seluruh elemen interaktif pada Android wajib memiliki area sentuh minimal **`48 x 48 dp`** agar mudah dioperasikan di lingkungan proyek/gudang.
  * Aplikasi Desktop wajib menyediakan pintasan papan ketik dasar (`Ctrl+K` atau `/` untuk fokus ke bilah pencarian global, `Esc` untuk menutup modal).
* **`SRS-QAL-015` (Konsistensi Status UI):** Setiap operasi jaringan asinkron wajib menampilkan *loading state* (*skeleton/spinner*), *empty state* yang informatif saat data kosong, dan *snackbar/toast* konfirmasi keberhasilan atau kegagalan yang jelas.

### G. Maintainability, Testability & Portability (Pemeliharaan, Pengujian & Portabilitas)
* **`SRS-QAL-016` (Standar Kualitas Kode & Static Analysis):** Kode Backend (TypeScript `strict: true`, ESLint) dan Flutter (`dart analyze`, `flutter_lints`) wajib bebas dari *error* kompilasi dan *lint warning* kritis sebelum rilis.
* **`SRS-QAL-017` (Migrasi Skema Terkendali):** Seluruh perubahan struktur database wajib dikelola melalui berkas migrasi berversi Prisma (`prisma migrate deploy`); perubahan skema manual langsung di database produksi dilarang.
* **`SRS-QAL-018` (Cakupan Pengujian Otomatis):**
  * Backend wajib memiliki *automated unit & integration tests* dengan cakupan kode (*code coverage*) minimal **$\ge 80\%$** pada modul kritis (Auth, RBAC, Update Kondisi, Transfer 2 Tahap, Audit Log, dan Konkurensi).
  * Klien Flutter wajib memiliki *unit/widget test* pada *provider* state inti, *API interceptor*, dan validasi formulir foto bukti.
* **`SRS-QAL-019` (Portabilitas Lingkungan):** Seluruh tumpukan server wajib dapat dijalankan di lingkungan baru (On-Premise maupun Cloud VPS) melalui perintah tunggal `docker compose up -d` setelah pengisian berkas `.env`.

---

## 3.12 Design and Implementation Constraints

* **`SRS-CON-001` (Penguncian Tech Stack):** Implementasi wajib mematuhi teknologi yang telah ditetapkan: Flutter (Desktop Windows/Linux + Android SDK 26+), Node.js 20 LTS + TypeScript + Express + Prisma ORM, PostgreSQL 16, Nginx, Docker Compose, dan Python 3 untuk skrip migrasi Excel.
* **`SRS-CON-002` (Kepatuhan Model RBAC & Transfer 2 Tahap):** Tidak diperkenankan membuat jalan pintas mutasi stok langsung lintas lokasi oleh `ADMIN_GUDANG` atau `PETUGAS_LAPANGAN`; seluruh perpindahan lintas lokasi wajib melalui siklus `IN_TRANSIT` $\rightarrow$ `RECEIVED`/`REJECTED`/`CANCELLED`.
* **`SRS-CON-003` (Versioning API):** Seluruh endpoint wajib menggunakan prefiks versi (`/api/v1/...`) guna menjamin kompatibilitas mundur (*backward compatibility*) saat pembaruan aplikasi Android diluncurkan secara bertahap di lapangan.
* **`SRS-CON-004` (Kesesuaian Baseline Excel `Nov 25`):** Data awal produksi wajib berasal langsung dari proses migrasi terverifikasi `Nov 25` (`531` item, `12.808` unit) tanpa penyuntingan manual pada database.

---

## 3.13 Personnel-Related Requirements & Human Factors

* **`SRS-PER-001` (Profil & Kapasitas Personel):** Sistem dirancang untuk mendukung hingga `50` pengguna terdaftar aktif (`2` Super Admin, `4–6` Admin Gudang, `15–25` Petugas Lapangan di Site PTS & Site Non PTS, dan `5–10` Viewer manajemen termasuk Pak Hanif & Vika) dengan tingkat literasi komputer dasar hingga menengah.
* **`SRS-PER-002` (Mitigasi Kesalahan Manusia / Human Factors):**
  * Label aksi menggunakan kata kerja Bahasa Indonesia yang tegas dan tidak ambigu (contoh: *"Kirim ke Lokasi Lain"*, *"Konfirmasi Terima Barang"*, *"Laporkan Kerusakan + Foto"*).
  * Validasi input dilakukan secara *inline* sebelum tombol kirim aktif (misal: mencegah input angka desimal/negatif atau jumlah melebihi saldo tersedia).
  * Pesan kesalahan wajib menjelaskan **apa yang salah** dan **tindakan perbaikan yang harus dilakukan pengguna** (contoh: *"Stok Good di Warehouse 1 hanya tersisa 3 unit. Kurangi jumlah transfer atau muat ulang data."*).

---

## 3.14 Training-Related Requirements

* **`SRS-TRN-001` (Panduan Pengguna Berbasis Peran):** Proyek wajib menyertakan buku panduan ringkas bergambar dalam Bahasa Indonesia (format PDF & Markdown) yang terbagi menjadi: (1) Panduan Admin & Viewer Desktop, (2) Panduan Petugas Lapangan Android, dan (3) Runbook Operasional IT/Server.
* **`SRS-TRN-002` (Lingkungan Sandbox / Pelatihan):** Tersedia konfigurasi `docker-compose.staging.yml` dengan data contoh (*seed data*) agar tim gudang dan petugas lapangan dapat berlatih melakukan mutasi dan transfer 2 tahap tanpa mencemari log audit ISO 9001 produksi.

---

## 3.15 Logistics-Related Requirements

* **`SRS-LOG-001` (Versioning & Distribusi APK Internal):** Aplikasi mengikuti *Semantic Versioning* (`MAJOR.MINOR.PATCH`). Backend menyediakan informasi versi minimum/terbaru pada `GET /api/v1/health` sehingga klien Android & Desktop dapat menampilkan notifikasi ringan apabila tersedia versi pembaruan APK/installer internal.
* **`SRS-LOG-002` (Pemantauan Kapasitas Disk & Backup):** Runbook operasional wajib menyertakan prosedur pemeriksaan rutin status backup harian dan peringatan administrator apabila kapasitas penyimpanan server melebihi `80%`.
* **`SRS-LOG-003` (Transisi Paralel / Cutover Aman):** Selama `2 minggu` pertama masa implementasi, sistem dirancang dapat berjalan paralel dengan pencatatan eksisting PT HTI melalui fitur ekspor Excel berkala untuk memudahkan rekonsiliasi transisi tanpa mengganggu operasional gudang maupun proyek.

---

## 3.16 Other Requirements

* **`SRS-OTH-001` (Identitas Korporat & Format Dokumen Resmi):** Seluruh laporan PDF dan Excel hasil ekspor wajib menampilkan identitas resmi **PT Hikari Teknologi Indonesia**, referensi kepatuhan **ISO 9001:2015 / ISO 45001:2018**, dan ruang pengesahan audit.
* **`SRS-OTH-002` (Kepemilikan Hak Kekayaan Intelektual & Lisensi OSS):** Seluruh kode sumber, skema database, dan dokumentasi menjadi milik penuh PT Hikari Teknologi Indonesia. Seluruh pustaka *open-source* pihak ketiga yang digunakan wajib berlisensi permisif yang aman untuk penggunaan internal/komersial (`MIT`, `Apache-2.0`, `BSD`, `ISC`).

---

## 3.17 Packaging Requirements

Paket serah terima (*deliverables*) rilis `v1.0.0` wajib dikemas secara terstruktur disertai nilai *checksum* `SHA-256` (`SRS-PKG-001` s.d. `SRS-PKG-004`):

| ID | Deliverable | Format Kemasan | Keterangan |
| :--- | :--- | :--- | :--- |
| `SRS-PKG-001` | Aplikasi Android Lapangan | `HTI-Inventory-v1.0.0-release.apk` (+ `.sha256`) | *Signed release APK* siap instalasi internal (Min SDK 26). |
| `SRS-PKG-002` | Aplikasi Desktop (Windows & Linux) | `HTI-Inventory-Setup-v1.0.0-win64.exe` & `HTI-Inventory-v1.0.0-linux-x64.AppImage` | *Standalone installer/bundle* tanpa dependensi manual. |
| `SRS-PKG-003` | Paket Server Hybrid Docker | `backend/` + `Dockerfile` + `docker-compose.yml` + `nginx.conf` + `.env.example` + skrip `backup.sh` / `restore.sh` | Siap *deploy* di Cloud VPS maupun Server Lokal PT HTI. |
| `SRS-PKG-004` | Paket Migrasi & Dokumentasi | `migration/` (Python ETL + Verifier) + `docs/` (SRS ini, OpenAPI/Swagger spec, Deployment Runbook, User Manuals) | Lengkap dengan hasil laporan rekonsiliasi `Nov 25`. |

---

## 3.18 Precedence and Criticality of Requirements

Kebutuhan pada dokumen ini tidak memiliki bobot yang sama; prioritas implementasi dan kriteria kelulusan *User Acceptance Test* (UAT) mengikuti tingkatan kekritisan berikut:

| Tingkat Kekritisan | Kategori | Kelompok Requirement Terkait | Kebijakan Rilis (*Release Gate*) |
| :--- | :--- | :--- | :--- |
| **P0 — CRITICAL** | Keselamatan K3 (ISO 45001), Keamanan (OWASP), Integritas Data & Audit ISO 9001 | `SRS-CAP-001`–`003`, `010`–`011`, `015`–`018`, `022`, `026`; `SRS-DAT-001`–`002`; `SRS-SAF-001`–`006`; `SRS-SEC-001`–`015`; `SRS-QAL-004`, `008`–`009` | **Wajib 100% lulus** tanpa cacat terbuka (*zero blocker*). Rilis dibatalkan bila gagal. |
| **P1 — HIGH** | Operasi Inti, Performa `< 500 ms`, Kontrak API & Deployment Hybrid | `SRS-CAP-004`–`009`, `012`–`014`, `019`–`021`, `023`–`025`; `SRS-EIF-001`–`007`; `SRS-QAL-001`–`003`, `007`, `019`; `SRS-ADP-001`–`003` | **Wajib lulus penuh** sebelum *go-live* operasional. |
| **P2 — MEDIUM** | Observabilitas, UX Lanjutan, Mode Degradasi, Pelatihan & Pemaketan | `SRS-MOD-002`–`003`; `SRS-QAL-005`–`006`, `010`–`018`; `SRS-PER-001`–`002`; `SRS-TRN-001`–`002`; `SRS-LOG-001`–`003`; `SRS-PKG-001`–`004` | Wajib terpenuhi pada rilis produksi `v1.0.0`; penyimpangan minor hanya boleh ditunda dengan persetujuan tertulis PM & QA. |
| **P3 — LOW** | Kesiapan Pengembangan Lanjutan | Ekstensibilitas `StorageService` ke S3/MinIO (`SRS-IIF-002`), kesiapan SKU `item_code` untuk QR/Barcode fase berikutnya | Memastikan desain tidak menutup jalur ekspansi fase 2. |

---

# 4. QUALIFICATION PROVISIONS

## 4.1 Definisi Metode Kualifikasi (MIL-STD-498)

Verifikasi pemenuhan setiap kebutuhan pada Bagian 3 menggunakan empat metode kualifikasi baku berikut:

* **D — Demonstration (Demonstrasi):** Pengoperasian langsung perangkat lunak (Desktop/Android) untuk membuktikan perilaku fungsional yang dapat diamati tanpa memerlukan instrumen pengujian khusus.
* **T — Test (Pengujian Terukur):** Pengoperasian perangkat lunak menggunakan skrip pengujian otomatis, instrumen beban (*load testing*), pemindai keamanan, atau *test harness* untuk mengumpulkan data kuantitatif terhadap ambang penerimaan.
* **A — Analysis (Analisis):** Evaluasi matematis, pemrosesan metrik uji beban, peninjauan *query execution plan* (`EXPLAIN ANALYZE`), atau verifikasi rekonsiliasi data log/backup.
* **I — Inspection (Inspeksi):** Pemeriksaan visual/statis terhadap kode sumber, berkas konfigurasi Docker/Nginx, skema DDL/Prisma, lisensi dependensi, dan kelengkapan dokumentasi.

## 4.2 Matriks Kualifikasi Kebutuhan (Verification Matrix)

| Kelompok Requirement | Metode | Instrumen / Prosedur Verifikasi | Kriteria Lulus Objektif (*Pass Criteria*) |
| :--- | :---: | :--- | :--- |
| `SRS-MOD-001` – `006` | `D`, `T` | Simulasi putus jaringan (*Airplane mode* Android), aktifkan *maintenance flag*, uji restore | Tidak ada *crash*, input form/foto tetap utuh, tombol *Retry* berfungsi, HTTP `503` tampil saat maintenance. |
| `SRS-CAP-001` – `005` | `T`, `D` | *Integration Test* (Jest/Supertest) untuk seluruh 4 role + *token expiry/rotation test* | `ADMIN_GUDANG` & `PETUGAS_LAPANGAN` mendapat `403` saat tulis lokasi lain; `VIEWER` mendapat `403` di semua endpoint tulis; refresh token lama tertolak pasca rotasi. |
| `SRS-CAP-006` – `009` | `T`, `D`, `A` | Uji pencarian 531+ item & `EXPLAIN ANALYZE` pada PostgreSQL (`pg_trgm`) | Hasil akurat untuk pencarian parsial, breakdown 4 lokasi cocok, item *soft-deleted* tidak tampil. |
| `SRS-CAP-010` – `015` | `T`, `D` | Uji transisi kondisi, uji blokir tanpa foto, *parallel concurrency test* (2 request bersamaan pada versi sama) | Transisi ke `SERVICE`/`BROKEN` tanpa `photo_url` ditolak `400`; salah satu dari 2 request paralel menerima `409 Conflict`; saldo tidak pernah `< 0`. |
| `SRS-CAP-016` – `019` | `T`, `D` | Skenario *end-to-end* transfer `WH-1` $\rightarrow$ `SITE-PTS` (Terima, Tolak, Batal) lintas akun Desktop & Android | Total unit sistem tetap konstan sepanjang siklus `IN_TRANSIT`, `RECEIVED`, `REJECTED`, dan `CANCELLED`. |
| `SRS-CAP-020` – `024` | `D`, `I`, `T` | Bandingkan KPI Dashboard & file ekspor `.xlsx`/`.pdf` terhadap kueri agregasi SQL langsung | Angka 100% identik; PDF memuat kop resmi PT HTI & blok tanda tangan; tidak ada endpoint ubah/hapus `stock_logs`. |
| `SRS-CAP-025` – `026` | `T`, `A` | Jalankan `HTI-TEIS-MIG-01` terhadap `2025 NEW ASSET TOOL & EQUIPMENT (2).xlsx` (`Nov 25`) | Assertion otomatis lulus: `9` kategori, `4` lokasi, `531` item, `10.340` Good, `119` Service, `2.349` Broken, **`12.808` Total**. |
| `SRS-EIF-001` – `007` | `T`, `D`, `I` | Validasi kontrak OpenAPI/JSON schema, uji kamera Android fisik, uji tombol *Test Connection* | Envelope JSON konsisten di seluruh endpoint; kompresi foto $\le 2\text{ MB}$; ganti URL LAN $\leftrightarrow$ Cloud berhasil tanpa *rebuild*. |
| `SRS-IIF-001` – `003`, `SRS-CON-*` | `I` | *Architecture & Code Review* pada repositori `backend/` dan `app/` | Pemisahan lapisan bersih, `StorageService` terabstraksi, *tech stack* sesuai ketetapan. |
| `SRS-DAT-001` – `006` | `I`, `T` | Inspeksi `prisma/schema.prisma`, uji constraint DB (`CHECK`, `UNIQUE`, `ON DELETE RESTRICT`), cek zona waktu | Database menolak saldo negatif dan *hard delete* item berelasi log; indeks `pg_trgm` aktif. |
| `SRS-SAF-001` – `006` | `D`, `I`, `T` | Inspeksi UI kontras warna+ikon, uji konfirmasi 2 langkah, uji *double-tap* pada Android | Tidak terjadi mutasi ganda saat ketukan cepat; peringatan K3 tampil jelas. |
| `SRS-SEC-001` – `015` | `T`, `I` | *Security Test* (SQLi/XSS/IDOR, rate-limit brute-force, unggah file palsu, cek EXIF strip, uji *refresh token reuse* & *force-logout*, uji *Excel formula injection* `=CMD\|...`, inspeksi Dockerfile non-root, port `5432` internal-only, backup terenkripsi `AES-256`, `npm audit`) | Login diblokir `429` pada percobaan ke-11; file non-gambar ditolak; akses foto tanpa JWT ditolak `401`; metadata EXIF/GPS kosong; reuse token mencabut semua sesi; sel formula terekspor sebagai teks aman; kontainer non-root; 0 Critical/High CVE; tidak ada rahasia di Git/log. |
| `SRS-ENV-*`, `SRS-RES-*` | `T`, `A`, `I` | Uji instalasi di Windows 11, Linux x64, Android 8–15, serta *profiling* RAM/CPU/APK size | APK $\le 50\text{ MB}$, *cold start* $\le 3\text{ s}$, RAM Desktop $\le 500\text{ MB}$, RAM Android $\le 200\text{ MB}$, CPU server puncak $\le 60\%$. |
| `SRS-QAL-001` – `003` | `T`, `A` | *Load Testing* menggunakan **`k6`** (50 *virtual users*, dataset 10.000 item) | Search p95 $\le 300\text{ ms}$ & p99 $\le 500\text{ ms}$; Mutasi p95 $\le 400\text{ ms}$; Export $\le 5\text{ s}$. |
| `SRS-QAL-004` – `019` | `T`, `A`, `I`, `D` | *Backup & Restore Drill*, inspeksi log JSON (`X-Request-Id`), *Coverage Report* (`jest --coverage`), *Usability Timing Test* | Restore penuh selesai $\le 2\text{ jam}$ tanpa kehilangan data; *coverage* modul kritis $\ge 80\%$; `dart analyze` & `eslint` 0 error; tugas lapangan selesai $\le 60\text{ s}$. |
| `SRS-PER-*`, `SRS-TRN-*`, `SRS-LOG-*`, `SRS-OTH-*`, `SRS-PKG-*` | `I`, `D` | Audit paket serah terima (*checksum SHA-256*), peninjauan manual pengguna, uji jalankan `docker-compose.staging.yml` | Seluruh artefak paket lengkap, *checksum* cocok, lisensi OSS permisif, panduan Bahasa Indonesia tersedia. |

---

# 5. REQUIREMENTS TRACEABILITY

## 5.1 System-Level Requirements Catalog (`SYS-001` – `SYS-012`)

| System Req ID | Kebutuhan Tingkat Sistem / Bisnis PT HTI | Sumber / Acuan |
| :--- | :--- | :--- |
| `SYS-001` | Digitalisasi & migrasi akurat 100% aset eksisting `Nov 25` (`531` item, `12.808` unit, 4 lokasi, 9 kategori) | Baseline Excel `Nov 25` |
| `SYS-002` | Pencarian ketersediaan & lokasi alat secara instan lintas 4 lokasi operasional | Operasional Gudang & Site |
| `SYS-003` | Kontrol keamanan akses berbasis lokasi (**Read Global, Write Local**) bagi 4 peran pengguna | Tata Kelola Manajemen PT HTI |
| `SYS-004` | Pelacakan kondisi keandalan alat (`Good`, `Service`, `Broken`) disertai bukti foto fisik K3 | **ISO 45001:2018** |
| `SYS-005` | Akuntabilitas mutasi alat lintas lokasi (2 tahap `In-Transit`) dan penugasan kode proyek (`job_code`) | **ISO 9001:2015** & Operasional |
| `SYS-006` | Jejak audit (*Audit Trail*) imutabel & ekspor laporan kepatuhan resmi (Excel/PDF) | **ISO 9001:2015** (Klausul 7.5 & 8.5.2) |
| `SYS-007` | Aplikasi lintas platform terpadu: Desktop (Admin/Monitoring) & Android (Teknisi Lapangan) | Blueprint Arsitektur PT HTI |
| `SYS-008` | Keamanan aplikasi & privasi data pengguna berstandar industri | OWASP ASVS L2 / MASVS / UU PDP |
| `SYS-009` | Performa tinggi (`< 500 ms`), reliabilitas ACID, anti *race-condition*, dan ketahanan jaringan lapangan | Standar Aplikasi Proper (`ISO/IEC 25010`) |
| `SYS-010` | Ketersediaan tinggi ($\ge 99.5\%$), observabilitas, serta backup & pemulihan bencana otomatis | Standar Aplikasi Proper & ISO 9001 |
| `SYS-011` | Fleksibilitas deployment Hybrid (On-Premise LAN/VPN maupun Cloud VPS) via Docker | Strategi Infrastruktur PT HTI |
| `SYS-012` | Kemudahan pemeliharaan, pengujian otomatis, pelatihan pengguna, dan pemaketan rilis rapi | Tata Kelola Rekayasa Perangkat Lunak |

## 5.2 Bidirectional Requirements Traceability Matrix (RTM)

| System Req ID | CSCI Requirements (`SRS-*`) yang Memenuhi | Metode Verifikasi Utama |
| :--- | :--- | :--- |
| `SYS-001` | `SRS-MOD-004`, `SRS-CAP-026`, `SRS-DAT-001`, `SRS-DAT-003`, `SRS-CON-004` | `T`, `A` (Migrasi & Rekonsiliasi) |
| `SYS-002` | `SRS-CAP-006`, `SRS-CAP-007`, `SRS-CAP-008`, `SRS-CAP-009`, `SRS-CAP-020`, `SRS-CAP-021`, `SRS-DAT-004`, `SRS-QAL-001` | `T`, `D`, `A` |
| `SYS-003` | `SRS-CAP-001`, `SRS-CAP-002`, `SRS-CAP-003`, `SRS-CAP-004`, `SRS-CAP-005`, `SRS-CAP-025`, `SRS-SEC-006`, `SRS-CON-002` | `T`, `D` |
| `SYS-004` | `SRS-CAP-010`, `SRS-CAP-011`, `SRS-EIF-006`, `SRS-SAF-001`, `SRS-SAF-002`, `SRS-SAF-003`, `SRS-RES-006` | `T`, `D`, `I` |
| `SYS-005` | `SRS-CAP-012`, `SRS-CAP-013`, `SRS-CAP-014`, `SRS-CAP-016`, `SRS-CAP-017`, `SRS-CAP-018`, `SRS-CAP-019`, `SRS-SAF-004` | `T`, `D` |
| `SYS-006` | `SRS-CAP-022`, `SRS-CAP-023`, `SRS-CAP-024`, `SRS-DAT-002`, `SRS-DAT-005`, `SRS-DAT-006`, `SRS-SAF-006`, `SRS-OTH-001` | `D`, `I`, `T` |
| `SYS-007` | `SRS-EIF-001`–`005`, `SRS-IIF-003`, `SRS-ENV-002`, `SRS-ENV-003`, `SRS-RES-001`–`002`, `SRS-RES-004`–`005`, `SRS-ADP-004`, `SRS-QAL-013`–`015`, `SRS-PER-001`–`002` | `D`, `T`, `I` |
| `SYS-008` | `SRS-SEC-001`–`015`, `SRS-EIF-002`, `SRS-OTH-002` | `T`, `I` |
| `SYS-009` | `SRS-MOD-001`, `SRS-MOD-002`, `SRS-CAP-015`, `SRS-SAF-005`, `SRS-RES-003`, `SRS-RES-009`, `SRS-QAL-001`–`006`, `SRS-QAL-012` | `T`, `A`, `D` |
| `SYS-010` | `SRS-MOD-003`, `SRS-MOD-005`, `SRS-RES-010`, `SRS-QAL-007`–`011`, `SRS-LOG-002` | `T`, `A`, `I` |
| `SYS-011` | `SRS-EIF-007`, `SRS-IIF-002`, `SRS-ADP-001`–`003`, `SRS-ENV-001`, `SRS-RES-008`, `SRS-QAL-019`, `SRS-CON-001`, `SRS-PKG-003` | `D`, `I`, `T` |
| `SYS-012` | `SRS-IIF-001`, `SRS-RES-007`, `SRS-QAL-016`–`018`, `SRS-CON-003`, `SRS-TRN-001`–`002`, `SRS-LOG-001`, `SRS-LOG-003`, `SRS-PKG-001`–`002`, `SRS-PKG-004` | `I`, `T`, `D` |

*Catatan: 100% CSCI Requirements (`SRS-*`) di Bagian 3 terlacak kembali ke salah satu atau lebih kebutuhan tingkat sistem (`SYS-001` s.d. `SYS-012`) dan seluruh `SYS-*` telah terakomodasi sepenuhnya.*

---

# 6. NOTES

## 6.1 Abbreviations and Acronyms

| Singkatan | Kepanjangan / Arti |
| :--- | :--- |
| **ACID** | Atomicity, Consistency, Isolation, Durability |
| **API** | Application Programming Interface |
| **APK** | Android Application Package |
| **ASVS** | Application Security Verification Standard (OWASP) |
| **CIS** | Center for Internet Security (Container & Infrastructure Security Benchmark) |
| **CORS** | Cross-Origin Resource Sharing |
| **CSCI** | Computer Software Configuration Item |
| **CVE** | Common Vulnerabilities and Exposures |
| **DDL** | Data Definition Language |
| **DPAPI** | Data Protection Application Programming Interface (Windows) |
| **ETL** | Extract, Transform, Load |
| **EXIF** | Exchangeable Image File Format (metadata kamera/GPS pada foto) |
| **FPS** | Frames Per Second |
| **GIN** | Generalized Inverted Index (PostgreSQL) |
| **GPG** | GNU Privacy Guard (enkripsi berkas backup) |
| **HSE / K3** | Health, Safety, and Environment / Keselamatan dan Kesehatan Kerja |
| **HTI** | PT Hikari Teknologi Indonesia |
| **HTI-TEIS** | PT HTI Tool & Equipment Inventory System |
| **IDOR** | Insecure Direct Object Reference |
| **ISO** | International Organization for Standardization |
| **JSONB** | JavaScript Object Notation Binary (PostgreSQL) |
| **JWT** | JSON Web Token |
| **LAN** | Local Area Network |
| **LTS** | Long-Term Support |
| **MASVS** | Mobile Application Security Verification Standard (OWASP) |
| **MIL-STD** | Military Standard |
| **MTBF** | Mean Time Between Failures |
| **NFR** | Non-Functional Requirement |
| **ORM** | Object-Relational Mapping |
| **OSS** | Open-Source Software |
| **p95 / p99** | Persentil ke-95 / ke-99 (metrik distribusi latensi) |
| **PDP** | Pelindungan Data Pribadi (UU No. 27 Tahun 2022) |
| **RBAC** | Role-Based Access Control |
| **RPO / RTO** | Recovery Point Objective / Recovery Time Objective |
| **SKU** | Stock Keeping Unit (`item_code`) |
| **SRS** | Software Requirements Specification |
| **TLS** | Transport Layer Security |
| **UAT** | User Acceptance Testing |
| **UUID** | Universally Unique Identifier |
| **VCS** | Version Control System (Git) |
| **VPS** | Virtual Private Server |
| **WAL** | Write-Ahead Logging (PostgreSQL) |
| **WIB** | Waktu Indonesia Barat (`UTC+7` / `Asia/Jakarta`) |

## 6.2 Glossary & Domain Definitions

* **Read Global, Write Local:** Kebijakan otorisasi PT HTI di mana seluruh pengguna terautentikasi dapat melihat stok dan mencari alat di semua 4 lokasi operasional, namun operasi tulis/mutasi hanya diizinkan pada lokasi tugas masing-masing (kecuali `SUPER_ADMIN` yang memiliki akses penuh dan `VIEWER` yang bersifat baca-saja).
* **In-Transit (`qty_in_transit`):** Status sementara unit alat yang telah dikirim keluar dari lokasi asal (`TRANSFER_OUT`) dan sedang menunggu konfirmasi penerimaan (`TRANSFER_IN`) atau penolakan (`TRANSFER_REJECT`) oleh petugas lokasi tujuan.
* **Optimistic Locking:** Mekanisme kontrol konkurensi menggunakan kolom `version` pada `item_stocks` untuk mendeteksi dan mencegah penimpaan data secara tidak sengaja ketika dua pengguna mengubah item yang sama pada saat bersamaan.
* **Soft Delete:** Penandaan item sebagai tidak aktif (`is_active = FALSE`, `deleted_at = TIMESTAMP`) alih-alih menghapus baris secara fisik, demi menjaga keutuhan relasi *Audit Trail* ISO 9001:2015.
* **Job Code:** Kode identifikasi proyek/pekerjaan lapangan (misal `1p-31-180`) tempat suatu peralatan dialokasikan atau sedang digunakan.
* **Evidence Photo (Bukti Foto K3):** Berkas gambar terkompresi yang wajib diunggah sebagai bukti objektif kondisi fisik peralatan saat ditandai `Service` atau `Broken` guna memenuhi kepatuhan ISO 45001:2018.

---

# 7. APPENDIX A — BASELINE DATA (`Nov 25`) & DATABASE SCHEMA REFERENCE

## A.1 Matriks Distribusi Stok Baseline (`Nov 25`)

Sumber: `2025 NEW ASSET TOOL & EQUIPMENT (2).xlsx` — *Sheet* `Nov 25` (`531` item spesifik).

| Kode Lokasi (`code`) | Nama Lokasi (`name`) | Tipe | Good (Unit) | Service (Unit) | Broken (Unit) | Total Volume |
| :--- | :--- | :--- | ---: | ---: | ---: | ---: |
| `WH-1` | `Warehouse 1` | `WAREHOUSE` | 8.096 | 111 | 2.242 | 10.449 |
| `WH-2` | `Warehouse 2` | `WAREHOUSE` | 1.830 | 8 | 107 | 1.945 |
| `SITE-NON-PTS` | `Site Non PTS` | `SITE` | 214 | 0 | 0 | 214 |
| `SITE-PTS` | `Site PTS` | `SITE` | 200 | 0 | 0 | 200 |
| **TOTAL** | **Seluruh Lokasi** | — | **10.340** | **119** | **2.349** | **12.808** |

## A.2 Taksonomi 9 Kategori Master & Prefix SKU

| No. | Kode (`categories.code`) | Nama Kategori (`categories.name`) | Contoh Item |
| :---: | :---: | :--- | :--- |
| 1 | `EQP` | `EQUIPMENT` | Crane, Genset, Compressor, Air Dryer, Mesin Bubut |
| 2 | `TLS` | `TOOLS` | General maintenance tools |
| 3 | `ELP` | `ELECTRICAL & PNEUMATIC TOOLS` | Bor listrik, Grinding machine, Cable reel |
| 4 | `MSR` | `MEASURING TOOLS` | Caliper, Mikrometer, Waterpass, Dial gauge |
| 5 | `HND` | `HAND TOOLS` | Kunci pas/ring, Palu, Tang, Tang potong |
| 6 | `LFT` | `LIFTING AND PULLING TOOLS` | Webbing sling, Chain block, Shackle, Lever block |
| 7 | `WHI` | `INVENTARIS WAREHOUSE` | Rak gudang, Meja kerja, Tangga, Troly |
| 8 | `QCT` | `QUALITY CONTROL (QC) TOOLS` | Instrumentasi pengujian mutu ISO |
| 9 | `SFT` | `INVENTARIS SAFETY` | Body harness, Safety helmet, APD K3 ISO 45001 |

## A.3 Ringkasan Entitas Basis Data (`PostgreSQL 16`)

| No. | Tabel | Kunci Utama & Unik | Tujuan Utama |
| :---: | :--- | :--- | :--- |
| 1 | `categories` | `id` (PK), `code` (UQ), `name` (UQ) | Master 9 kategori alat & prefix SKU |
| 2 | `locations` | `id` (PK), `code` (UQ), `name` (UQ) | Master 4+ lokasi operasional (Gudang & Site) |
| 3 | `items` | `id` (PK), `item_code` (UQ) | Master 531+ item spesifik (*soft delete* aktif) |
| 4 | `users` | `id` (PK), `username` (UQ) | Akun pengguna, hash kata sandi, `role`, `assigned_location_id` |
| 5 | `refresh_tokens` | `id` (PK), `token_hash` (UQ) | Manajemen sesi & rotasi refresh token Desktop/Android |
| 6 | `item_stocks` | `id` (PK), `(item_id, location_id)` (UQ) | Saldo real-time (`good`, `service`, `broken`, `in_transit`), `job_code`, `remarks`, `version` |
| 7 | `stock_transfers` | `id` (PK), `transfer_code` (UQ) | Siklus transfer 2 tahap (`IN_TRANSIT` $\rightarrow$ `RECEIVED`/`REJECTED`/`CANCELLED`) |
| 8 | `stock_logs` | `id` (PK) | Audit trail imutabel ISO 9001 (`qty_before`/`qty_after` JSONB) & `photo_url` ISO 45001 |

*(DDL SQL dan skema Prisma lengkap tersedia pada `docs/LLD_PT_HTI_Tool_Equipment_Inventory_System.md` Bagian 2 serta `backend/prisma/`.)*
