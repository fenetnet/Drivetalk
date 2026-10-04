#!/usr/bin/env bash
# Applies new files from supabase/migrations to the real database, once each.
# Used by .github/workflows/supabase-migrate.yml with the SUPABASE_DB_URL
# secret (never stored in git). Files the owner already pasted by hand are
# recognised by an object they create and recorded without re-running.
set -euo pipefail
: "${SUPABASE_DB_URL:?missing}"
q() { psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -tAq -c "$1"; }

q "create table if not exists public.drivetalk_migrations (
     name text primary key, applied_at timestamptz not null default now());
   alter table public.drivetalk_migrations enable row level security;"

if [ "$(q "select count(*) from public.drivetalk_migrations")" = "0" ]; then
  # First run: record what is already there.
  declare -A sentinel=(
    [20261002000000_two_user_test.sql]="public.profiles"
    [20261003000000_auto_driving.sql]="public.device_tokens"
    [20261004000000_circles_quick_unblock.sql]="public.circles"
    [20261005000000_contacts.sql]="public.contact_hashes"
  )
  for f in "${!sentinel[@]}"; do
    if [ "$(q "select to_regclass('${sentinel[$f]}') is not null")" = "t" ]; then
      q "insert into public.drivetalk_migrations(name) values ('$f') on conflict do nothing"
      echo "already there: $f"
    fi
  done
fi

for path in $(ls supabase/migrations/*.sql | sort); do
  f=$(basename "$path")
  if [ "$(q "select count(*) from public.drivetalk_migrations where name = '$f'")" = "1" ]; then
    continue
  fi
  echo "applying: $f"
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 --single-transaction -q -f "$path"
  q "insert into public.drivetalk_migrations(name) values ('$f')"
done
echo "database is up to date"
