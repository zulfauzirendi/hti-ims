-- ==============================================================================
-- Migration: 20261122000001_init_hti_teis
-- PT HTI Tool & Equipment Inventory System (HTI-TEIS) — Initial Physical Schema
-- PostgreSQL 16 + pg_trgm + ACID CHECK Constraints + ISO 9001/45001 Audit Trail
-- ==============================================================================

-- 1. Extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. Enum Types
CREATE TYPE "LocationType" AS ENUM ('WAREHOUSE', 'SITE');
CREATE TYPE "UserRole" AS ENUM ('SUPER_ADMIN', 'ADMIN_GUDANG', 'PETUGAS_LAPANGAN', 'VIEWER');
CREATE TYPE "ConditionStatus" AS ENUM ('GOOD', 'SERVICE', 'BROKEN');
CREATE TYPE "TransferStatus" AS ENUM ('IN_TRANSIT', 'RECEIVED', 'REJECTED', 'CANCELLED');
CREATE TYPE "StockActionType" AS ENUM (
    'INITIAL_IMPORT',
    'STATUS_CHANGE',
    'STOCK_IN',
    'DISPOSAL',
    'TRANSFER_OUT',
    'TRANSFER_IN',
    'TRANSFER_REJECT',
    'TRANSFER_CANCEL',
    'REMARKS_UPDATE'
);

-- 3. Table: categories
CREATE TABLE "categories" (
    "id" SERIAL NOT NULL,
    "code" VARCHAR(10) NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "categories_code_key" ON "categories"("code");
CREATE UNIQUE INDEX "categories_name_key" ON "categories"("name");

-- 4. Table: locations
CREATE TABLE "locations" (
    "id" SERIAL NOT NULL,
    "code" VARCHAR(20) NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "location_type" "LocationType" NOT NULL DEFAULT 'WAREHOUSE',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "locations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "locations_code_key" ON "locations"("code");
CREATE UNIQUE INDEX "locations_name_key" ON "locations"("name");

-- 5. Table: items (Soft Delete for ISO 9001 Audit Integrity)
CREATE TABLE "items" (
    "id" SERIAL NOT NULL,
    "item_code" VARCHAR(30) NOT NULL,
    "category_id" INTEGER NOT NULL,
    "description" VARCHAR(255) NOT NULL,
    "specification" TEXT,
    "unit" VARCHAR(20) NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "deleted_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "items_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "items_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "items_item_code_key" ON "items"("item_code");
CREATE INDEX "idx_items_category" ON "items"("category_id");
CREATE INDEX "idx_items_active_category" ON "items"("category_id") WHERE "is_active" = true;
CREATE INDEX "idx_items_description_trgm" ON "items" USING GIN ("description" gin_trgm_ops);
CREATE INDEX "idx_items_spec_trgm" ON "items" USING GIN ("specification" gin_trgm_ops);
CREATE INDEX "idx_items_code_trgm" ON "items" USING GIN ("item_code" gin_trgm_ops);

-- 6. Table: users
CREATE TABLE "users" (
    "id" SERIAL NOT NULL,
    "username" VARCHAR(50) NOT NULL,
    "password_hash" VARCHAR(255) NOT NULL,
    "full_name" VARCHAR(100) NOT NULL,
    "role" "UserRole" NOT NULL,
    "assigned_location_id" INTEGER,
    "must_change_password" BOOLEAN NOT NULL DEFAULT true,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "users_assigned_location_id_fkey" FOREIGN KEY ("assigned_location_id") REFERENCES "locations"("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "chk_users_role_location" CHECK (
        ("role" IN ('SUPER_ADMIN', 'VIEWER') AND "assigned_location_id" IS NULL)
        OR ("role" IN ('ADMIN_GUDANG', 'PETUGAS_LAPANGAN') AND "assigned_location_id" IS NOT NULL)
    )
);

CREATE UNIQUE INDEX "users_username_key" ON "users"("username");

-- 7. Table: refresh_tokens (Multi-Device Sessions & Reuse Detection)
CREATE TABLE "refresh_tokens" (
    "id" SERIAL NOT NULL,
    "user_id" INTEGER NOT NULL,
    "family_id" UUID NOT NULL,
    "token_hash" VARCHAR(64) NOT NULL,
    "device_info" VARCHAR(150),
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "revoked_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "refresh_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "refresh_tokens_token_hash_key" ON "refresh_tokens"("token_hash");
CREATE INDEX "idx_refresh_tokens_user_family" ON "refresh_tokens"("user_id", "family_id");

-- 8. Table: item_stocks (Real-Time Ledger + Optimistic Locking)
CREATE TABLE "item_stocks" (
    "id" SERIAL NOT NULL,
    "item_id" INTEGER NOT NULL,
    "location_id" INTEGER NOT NULL,
    "qty_good" INTEGER NOT NULL DEFAULT 0,
    "qty_service" INTEGER NOT NULL DEFAULT 0,
    "qty_broken" INTEGER NOT NULL DEFAULT 0,
    "qty_in_transit" INTEGER NOT NULL DEFAULT 0,
    "job_code" VARCHAR(255),
    "remarks" TEXT,
    "version" INTEGER NOT NULL DEFAULT 1,
    "updated_by" INTEGER,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "item_stocks_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "item_stocks_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "items"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "item_stocks_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "locations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "item_stocks_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "chk_stocks_non_negative" CHECK (
        "qty_good" >= 0 AND "qty_service" >= 0 AND "qty_broken" >= 0 AND "qty_in_transit" >= 0
    )
);

CREATE UNIQUE INDEX "unique_item_location" ON "item_stocks"("item_id", "location_id");
CREATE INDEX "idx_item_stocks_location" ON "item_stocks"("location_id");

-- 9. Table: stock_transfers (2-Stage Inter-Location Workflow)
CREATE TABLE "stock_transfers" (
    "id" SERIAL NOT NULL,
    "transfer_code" VARCHAR(40) NOT NULL,
    "item_id" INTEGER NOT NULL,
    "from_location_id" INTEGER NOT NULL,
    "to_location_id" INTEGER NOT NULL,
    "condition_status" "ConditionStatus" NOT NULL DEFAULT 'GOOD',
    "qty" INTEGER NOT NULL,
    "status" "TransferStatus" NOT NULL DEFAULT 'IN_TRANSIT',
    "job_code" VARCHAR(255),
    "sender_note" TEXT,
    "receiver_note" TEXT,
    "sent_by" INTEGER NOT NULL,
    "received_by" INTEGER,
    "sent_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMPTZ(6),

    CONSTRAINT "stock_transfers_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "stock_transfers_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "items"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "stock_transfers_from_location_id_fkey" FOREIGN KEY ("from_location_id") REFERENCES "locations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "stock_transfers_to_location_id_fkey" FOREIGN KEY ("to_location_id") REFERENCES "locations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "stock_transfers_sent_by_fkey" FOREIGN KEY ("sent_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "stock_transfers_received_by_fkey" FOREIGN KEY ("received_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "chk_transfer_qty_positive" CHECK ("qty" > 0),
    CONSTRAINT "chk_transfer_diff_locations" CHECK ("from_location_id" <> "to_location_id")
);

CREATE UNIQUE INDEX "stock_transfers_transfer_code_key" ON "stock_transfers"("transfer_code");
CREATE INDEX "idx_stock_transfers_incoming" ON "stock_transfers"("to_location_id", "status");
CREATE INDEX "idx_stock_transfers_outgoing" ON "stock_transfers"("from_location_id", "status");

-- 10. Table: stock_logs (Immutable Append-Only Audit Trail — ISO 9001 & ISO 45001)
CREATE TABLE "stock_logs" (
    "id" SERIAL NOT NULL,
    "item_id" INTEGER NOT NULL,
    "from_location_id" INTEGER,
    "to_location_id" INTEGER,
    "action_type" "StockActionType" NOT NULL,
    "status_changed" VARCHAR(40),
    "qty_changed" INTEGER NOT NULL,
    "qty_before" JSONB,
    "qty_after" JSONB,
    "job_code" VARCHAR(255),
    "note" TEXT,
    "photo_url" VARCHAR(500),
    "transfer_id" INTEGER,
    "user_id" INTEGER,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "stock_logs_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "stock_logs_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "items"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "stock_logs_from_location_id_fkey" FOREIGN KEY ("from_location_id") REFERENCES "locations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "stock_logs_to_location_id_fkey" FOREIGN KEY ("to_location_id") REFERENCES "locations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "stock_logs_transfer_id_fkey" FOREIGN KEY ("transfer_id") REFERENCES "stock_transfers"("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "stock_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX "idx_stock_logs_created_desc" ON "stock_logs"("created_at" DESC);
CREATE INDEX "idx_stock_logs_item_created" ON "stock_logs"("item_id", "created_at" DESC);

-- 11. Automatic updated_at Trigger for direct SQL updates
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_items_updated_at
    BEFORE UPDATE ON "items" FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_users_updated_at
    BEFORE UPDATE ON "users" FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_item_stocks_updated_at
    BEFORE UPDATE ON "item_stocks" FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
