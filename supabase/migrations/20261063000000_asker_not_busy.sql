-- DriveBond — the one who asks is never "busy" because of it (D-152).
--
-- "Asked enough" (D-103) stops questions to someone who doesn't answer:
-- 3 per free time, or on an automatic trip one they didn't say yes to.
-- It also counted questions the person had said yes to (their own taps,
-- the app's questions a friend didn't answer), and kept counting after
-- they were clearly back. So after a few unanswered tries, friends who
-- tried to call back got "busy". Now it counts only questions the person
-- did NOT say yes to, since their last yes or tap.

create or replace function public.asked_enough(p_user uuid, p_since timestamptz)
returns boolean language sql stable security definer set search_path = public as $$
  with since as (
    select greatest(p_since, coalesce((
      select max(greatest(o.created_at, o.updated_at)) from match_offers o
      where p_user in (o.user_a, o.user_b)
        and not o.quick
        and (case when p_user = o.user_a then o.a_response else o.b_response end) = 'accept'
        and o.created_at >= p_since), p_since)) as t
  ), unanswered as (
    select count(*) as n from match_offers o, since
    where p_user in (o.user_a, o.user_b)
      and not o.quick
      and o.created_at >= since.t
      and o.status in ('declined', 'expired', 'cancelled')
      and (case when p_user = o.user_a then o.a_response else o.b_response end)
          is distinct from 'accept'
  )
  select case
    when exists (select 1 from availability where user_id = p_user and source = 'auto')
      then (select n >= 1 from unanswered)
    else (select n >= 3 from unanswered)
  end;
$$;
revoke all on function public.asked_enough(uuid, timestamptz) from public, anon, authenticated;

-- Last: the version says 63 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 63 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261063000000_asker_not_busy') on conflict do nothing;

notify pgrst, 'reload schema';
