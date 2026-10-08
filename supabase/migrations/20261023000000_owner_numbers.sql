-- DriveBond — the numbers screen is for the owner only (D-085).
-- Totals only, as before; now refused to anyone who isn't the owner.

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 23 $$;
grant execute on function public.schema_version() to anon, authenticated;

create or replace function public.app_stats(p_days integer default 7)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  since timestamptz := now() - make_interval(days => least(greatest(coalesce(p_days, 7), 1), 365));
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not is_owner() then raise exception 'not_owner'; end if;
  return jsonb_build_object(
    'users', (select count(*) from profiles),
    'new_users', (select count(*) from profiles where created_at >= since),
    'active_users', (select count(*) from profiles where last_seen_at >= since),
    'friendships', (select count(*) from connections),
    'free_times', (select count(*) from app_events where name = 'availability_started' and created_at >= since),
    'offers', (select count(*) from match_offers where created_at >= since and not quick),
    'quick', (select count(*) from match_offers where created_at >= since and quick),
    'both_yes', (select count(*) from match_offers where created_at >= since and status = 'accepted'),
    'talked', (select count(*) from match_offers where created_at >= since and talked),
    'declined', (select count(*) from match_offers where created_at >= since and status = 'declined'),
    'later', (select count(*) from match_offers where created_at >= since and later_from is not null),
    'no_answer', (select count(*) from match_offers where created_at >= since and status = 'expired'),
    'reports', (select count(*) from reports where created_at >= since),
    'feedback', (select count(*) from feedback_notes where created_at >= since),
    'dial_ms', (select percentile_cont(0.5) within group (order by ms)
                from app_events where name = 'dial_started' and ms is not null and created_at >= since)
  );
end;
$$;
revoke all on function public.app_stats(integer) from public, anon;
grant execute on function public.app_stats(integer) to authenticated;

insert into public.drivetalk_migrations (name)
values ('20261023000000_owner_numbers') on conflict do nothing;
