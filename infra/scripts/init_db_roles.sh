#!/bin/sh
set -e

# Membuat peran runtime database berprinsip least-privilege (SRS-SEC-013)
# Password disuntikkan melalui variabel lingkungan APP_DB_PASSWORD.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE EXTENSION IF NOT EXISTS pg_trgm;

  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${APP_DB_USER}') THEN
      EXECUTE format('CREATE ROLE %I WITH LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT',
        '${APP_DB_USER}', '${APP_DB_PASSWORD}');
    END IF;
  END
  \$\$;

  GRANT CONNECT ON DATABASE "${POSTGRES_DB}" TO "${APP_DB_USER}";
  GRANT USAGE ON SCHEMA public TO "${APP_DB_USER}";
EOSQL
