-- ==============================================================================
-- Least-Privilege Runtime Grants & ISO 9001 Immutable Audit Trail Enforcement
-- Jalankan setelah `prisma migrate deploy` menggunakan role owner (hti_migrator)
-- ==============================================================================

-- 1. Cabut hak berlebih pada schema public
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM hti_app;

-- 2. Berikan hak operasi normal pada 7 tabel operasional
GRANT SELECT, INSERT, UPDATE, DELETE ON
  categories,
  locations,
  items,
  users,
  refresh_tokens,
  item_stocks,
  stock_transfers
TO hti_app;

-- 3. APPEND-ONLY pada stock_logs (SRS-SAF-006 & SRS-SEC-013)
-- Role runtime API dilarang keras mengubah atau menghapus jejak audit ISO 9001!
GRANT SELECT, INSERT ON stock_logs TO hti_app;
REVOKE UPDATE, DELETE, TRUNCATE ON stock_logs FROM hti_app;

-- 4. Hak penggunaan sequence untuk kolom SERIAL/autoincrement
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO hti_app;
