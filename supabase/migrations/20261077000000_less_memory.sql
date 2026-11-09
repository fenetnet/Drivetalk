-- DriveBond — a lighter load on the small free server (owner, 2026-11-09).
--
-- The free server ran out of memory twice (Reports: memory commitment
-- "SEVERE", swap full) and stopped answering until a manual restart.
-- Two small, safe steps that need no new app version:
--
-- 1. Every night, besides the earlier cleanup: Supabase's own logs that
--    nobody reads — one row for every run of our every-minute jobs
--    (~2,900 a day, kept forever by default) and the answers of sent
--    notifications — are kept for 2 days only.
-- 2. Every hour, "our own small restart": database connections that have
--    been sitting open and doing nothing for 15 minutes are closed. Each
--    holds memory; whoever needs a connection simply opens a new one.
--    Only ordinary connections of the app's API (role authenticator) and
--    of the dashboard / jobs (role postgres) — never Supabase's internal
--    services, replication or background workers, never a busy one.
--    If the server doesn't allow it, nothing happens (no error).
--
-- Older apps: nothing changes.

create or replace function public.nightly_cleanup()
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from app_events where created_at < now() - interval '90 days';
  delete from crash_reports where created_at < now() - interval '90 days';
  -- Old offers, except each pair's last talk ("last talked …").
  delete from match_offers o
  where o.created_at < now() - interval '90 days'
    and o.status <> 'pending'
    and not (coalesce(o.talked, false) and o.accepted_at = (
      select max(x.accepted_at) from match_offers x
      where x.user_a = o.user_a and x.user_b = o.user_b and x.talked));
  delete from contact_searches where at < now() - interval '2 days';
  delete from owner_claims where at < now() - interval '1 day';
  delete from pair_snoozes where until < now() - interval '1 day';
  delete from talk_intents where expires_at < now() - interval '1 day';
  delete from invitations where expires_at < now() - interval '30 days';
  -- Notifications (D-119…D-121).
  delete from push_outbox where created_at < now() - interval '2 days';
  delete from trip_pushes where sent_at < now() - interval '2 days';
  delete from push_tokens where updated_at < now() - interval '180 days';
  delete from push_state
  where key like 'version_told:%' and updated_at < now() - interval '30 days';
  -- Supabase's own logs (2026-11-09): each on its own, so one that is
  -- missing or not allowed never stops the rest.
  begin
    execute 'delete from cron.job_run_details '
            'where start_time < now() - interval ''2 days''';
  exception when others then null;
  end;
  begin
    execute 'delete from net._http_response '
            'where created < now() - interval ''2 days''';
  exception when others then null;
  end;
end;
$$;
revoke all on function public.nightly_cleanup() from public, anon, authenticated;

-- Close connections idle for 15 minutes. Returns how many were closed.
create or replace function private.close_idle_connections()
returns integer language plpgsql security definer set search_path = public as $$
declare
  n integer := 0;
  p integer;
begin
  for p in
    select a.pid from pg_stat_activity a
    where a.backend_type = 'client backend'
      and a.pid <> pg_backend_pid()
      and a.datname = current_database()
      and a.usename in ('authenticator', 'postgres')
      and a.state = 'idle'
      and a.state_change < now() - interval '15 minutes'
  loop
    begin
      if pg_terminate_backend(p) then n := n + 1; end if;
    exception when others then null;
    end;
  end loop;
  return n;
end;
$$;
revoke all on function private.close_idle_connections() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'drivetalk-close-idle') then
      perform cron.unschedule('drivetalk-close-idle');
    end if;
    perform cron.schedule('drivetalk-close-idle', '41 * * * *',
                          'select private.close_idle_connections()');
  end if;
exception when others then
  raise notice 'pg_cron not available: %', sqlerrm;
end;
$$;

-- Last: the version says 77 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 77 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261077000000_less_memory') on conflict do nothing;
