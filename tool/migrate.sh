#!/usr/bin/env bash
# Applies NEW files from supabase/migrations to the real database, once each,
# in order. Used by .github/workflows/supabase-migrate.yml with the
# SUPABASE_DB_URL secret (never stored in git).
#
# Safety:
# - Every file records its own name in public.drivetalk_migrations (without
#   ".sql"). Anything not newer than the newest recorded name is treated as
#   already there (the owner pasted the older files by hand, in order).
# - A database with tables but no record at all is refused (never re-run
#   old files on top of a live database).
# - DRY_RUN=1 only prints what would be applied.
set -euo pipefail
: "${SUPABASE_DB_URL:?missing}"
q() { psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -tAq -c "$1"; }

q "create table if not exists public.drivetalk_migrations (
     name text primary key, applied_at timestamptz not null default now());
   alter table public.drivetalk_migrations enable row level security;"

newest=$(q "select coalesce(max(replace(name, '.sql', '')), '') from public.drivetalk_migrations")
if [ -z "$newest" ] && [ "$(q "select to_regclass('public.profiles') is not null")" = "t" ]; then
  echo "::error::The database has DriveBond tables but no record of which updates ran. Stopping (nothing changed)."
  exit 1
fi
echo "newest update already in the database: ${newest:-none}"

applied=0
for path in $(ls supabase/migrations/*.sql | sort); do
  base=$(basename "$path" .sql)
  if [[ -n "$newest" && ! "$base" > "$newest" ]]; then
    continue
  fi
  if [ "$(q "select count(*) from public.drivetalk_migrations where name in ('$base', '$base.sql')")" != "0" ]; then
    continue
  fi
  if [ "${DRY_RUN:-}" = "1" ]; then
    echo "would apply: $base"
    continue
  fi
  echo "applying: $base"
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 --single-transaction -q -f "$path"
  q "insert into public.drivetalk_migrations(name) values ('$base') on conflict do nothing"
  applied=$((applied + 1))
done
echo "database is up to date ($applied new)"
if [ "$applied" -gt 0 ]; then
  echo "server version now: $(q "select schema_version()")"
fi
