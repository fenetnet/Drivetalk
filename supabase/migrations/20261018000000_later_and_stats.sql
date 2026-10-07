-- DriveTalk — "not now, I'll get back to you" and numbers for the owner (D-076).

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 18 $$;
grant execute on function public.schema_version() to anon, authenticated;

-- ------------------------------------------------------------ later note

-- Who said "not now — I'll get back to you" (the other side is told so).
alter table public.match_offers add column if not exists later_from uuid;

create or replace function public.decline_later(p_offer uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  r jsonb;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  r := answer_offer(p_offer, false);
  if r->>'status' = 'declined' then
    update match_offers set later_from = me, updated_at = now()
    where id = p_offer and me in (user_a, user_b);
  end if;
  return r;
end;
$$;
revoke all on function public.decline_later(uuid) from public, anon;
grant execute on function public.decline_later(uuid) to authenticated;

-- ------------------------------------------------------------ owner numbers

-- Totals only: no names, no numbers, nothing about a single person.
create or replace function public.app_stats(p_days integer default 7)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  since timestamptz := now() - make_interval(days => least(greatest(coalesce(p_days, 7), 1), 365));
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
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
    'dial_ms', (select percentile_cont(0.5) within group (order by ms)
                from app_events where name = 'dial_started' and ms is not null and created_at >= since)
  );
end;
$$;
revoke all on function public.app_stats(integer) from public, anon;
grant execute on function public.app_stats(integer) to authenticated;

insert into public.drivetalk_migrations (name)
values ('20261018000000_later_and_stats') on conflict do nothing;
