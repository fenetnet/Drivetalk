-- DriveBond — the owner's funnel (owner, 2026-11-07).
--
-- Of the people who joined in the period (one per phone number), how many
-- got a first friend, were free at least once, talked at least once, and
-- came back a week later. Counts only — no names, no numbers.
-- Older apps: the same keys as before, plus new ones they ignore.

create or replace function public.app_funnel(p_since timestamptz)
returns jsonb language sql stable security definer set search_path = public as $$
  with persons as (
    select n.phone_hash as h,
           min(p.created_at) as first_at,
           max(p.last_seen_at) as last_seen,
           array_agg(p.id) as ids
    from profiles p join phone_numbers n on n.user_id = p.id
    where n.phone_hash is not null
    group by n.phone_hash
  ), cohort as (
    select * from persons where first_at >= p_since
  )
  select jsonb_build_object(
    'funnel_joined', count(*),
    'funnel_friend', count(*) filter (where exists (
      select 1 from connections c
      where c.pending_for is null and (c.user_a = any(ids) or c.user_b = any(ids)))),
    -- free at least once: "I have time", or a question/trip with a friend
    -- (automatic trips leave no event of their own)
    'funnel_free', count(*) filter (where exists (
        select 1 from app_events e
        where e.name = 'availability_started' and e.user_id = any(ids))
      or exists (
        select 1 from match_offers o where o.user_a = any(ids) or o.user_b = any(ids))
      or exists (
        select 1 from availability a where a.user_id = any(ids))),
    'funnel_talked', count(*) filter (where exists (
      select 1 from match_offers o
      where o.talked and (o.user_a = any(ids) or o.user_b = any(ids)))),
    -- a week later: only who joined at least 7 days ago can count
    'funnel_week_base', count(*) filter (where first_at <= now() - interval '7 days'),
    'funnel_week_back', count(*) filter (where first_at <= now() - interval '7 days'
                                           and last_seen >= first_at + interval '7 days'))
  from cohort;
$$;
revoke all on function public.app_funnel(timestamptz) from public, anon, authenticated;

create or replace function public.app_stats(p_days integer default 7)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  since timestamptz := now() - make_interval(days => least(greatest(coalesce(p_days, 7), 1), 365));
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not is_owner() then raise exception 'not_owner'; end if;
  return jsonb_build_object(
    -- People: one per phone number.
    'users', (select count(distinct n.phone_hash)
              from profiles p join phone_numbers n on n.user_id = p.id
              where n.phone_hash is not null),
    'users_no_phone', (select count(*) from profiles p
                       where not exists (select 1 from phone_numbers n
                                         where n.user_id = p.id and n.phone_hash is not null)),
    'accounts', (select count(*) from profiles),
    -- New: a number seen for the first time in this period.
    'new_users', (select count(*) from (
                    select n.phone_hash, min(p.created_at) as first_at
                    from profiles p join phone_numbers n on n.user_id = p.id
                    where n.phone_hash is not null
                    group by n.phone_hash) x
                  where x.first_at >= since),
    'active_users', (select count(distinct n.phone_hash)
                     from profiles p join phone_numbers n on n.user_id = p.id
                     where n.phone_hash is not null and p.last_seen_at >= since),
    'active_no_phone', (select count(*) from profiles p
                        where p.last_seen_at >= since
                          and not exists (select 1 from phone_numbers n
                                          where n.user_id = p.id and n.phone_hash is not null)),
    -- Friendships between two different people (by number).
    'friendships', (select count(distinct (least(na.phone_hash, nb.phone_hash),
                                            greatest(na.phone_hash, nb.phone_hash)))
                    from connections c
                    join phone_numbers na on na.user_id = c.user_a
                    join phone_numbers nb on nb.user_id = c.user_b
                    where c.pending_for is null
                      and na.phone_hash is not null and nb.phone_hash is not null
                      and na.phone_hash <> nb.phone_hash),
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
    'feedback_people', (select count(distinct coalesce(n.phone_hash, f.user_id::text))
                        from feedback_notes f left join phone_numbers n on n.user_id = f.user_id
                        where f.created_at >= since and f.user_id is not null),
    'crashes', (select count(*) from crash_reports where created_at >= since),
    'crash_people', (select count(distinct coalesce(n.phone_hash, r.user_id::text))
                     from crash_reports r left join phone_numbers n on n.user_id = r.user_id
                     where r.created_at >= since and r.user_id is not null),
    'dial_ms', (select percentile_cont(0.5) within group (order by ms)
                from app_events where name = 'dial_started' and ms is not null and created_at >= since)
  ) || app_funnel(since);
end;
$$;
revoke all on function public.app_stats(integer) from public, anon;
grant execute on function public.app_stats(integer) to authenticated;

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 75 $$;

insert into public.drivetalk_migrations (name)
values ('20261075000000_owner_funnel') on conflict do nothing;

notify pgrst, 'reload schema';
