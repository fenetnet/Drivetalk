-- DriveBond — "when my friends are usually on the road" (owner, 2026-11-08,
-- item 4, option א).
--
-- Only for someone who turns it on (off by default): their regular times
-- (the routines they set, e.g. Sun–Thu 07:30 for 30 minutes) are shared
-- with their friends. Nothing is learned from history; turning it off
-- deletes them. Friends see them only if they could see that person as
-- free at all (approved, not blocked, not hidden, not rated "never").
-- Older apps: nothing changes.

create table if not exists public.usual_times (
  user_id uuid not null references public.profiles(id) on delete cascade,
  -- DateTime.weekday bits: Monday = 1 << 1 … Sunday = 1 << 7
  days smallint not null check (days between 2 and 254),
  start_minute smallint not null check (start_minute between 0 and 1439),
  minutes smallint not null check (minutes between 5 and 240),
  mode text not null check (mode in ('driving', 'walking', 'breakTime', 'free')),
  primary key (user_id, days, start_minute)
);
alter table public.usual_times enable row level security;
-- Only through the two functions below.
revoke all on public.usual_times from public, anon, authenticated;

-- Replace my shared times (an empty list = stop sharing).
create or replace function public.set_usual_times(p_times jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if jsonb_typeof(coalesce(p_times, '[]'::jsonb)) <> 'array'
     or jsonb_array_length(coalesce(p_times, '[]'::jsonb)) > 20 then
    raise exception 'invalid';
  end if;
  delete from usual_times where user_id = me;
  insert into usual_times (user_id, days, start_minute, minutes, mode)
  select me, (t ->> 'days')::smallint, (t ->> 'start')::smallint,
         (t ->> 'minutes')::smallint, t ->> 'mode'
  from jsonb_array_elements(coalesce(p_times, '[]'::jsonb)) t
  on conflict do nothing;
end;
$$;
revoke all on function public.set_usual_times(jsonb) from public, anon;
grant execute on function public.set_usual_times(jsonb) to authenticated;

-- My friends' shared times (only friends who could see me / I them).
create or replace function public.friends_usual_times()
returns table (user_id uuid, days smallint, start_minute smallint,
               minutes smallint, mode text)
language sql stable security definer set search_path = public as $$
  select u.user_id, u.days, u.start_minute, u.minutes, u.mode
  from usual_times u
  where u.user_id in (select friend_ids(auth.uid()))
    and u.user_id <> auth.uid()
    and not is_blocked_between(auth.uid(), u.user_id)
    and not awaits_approval(u.user_id, auth.uid())
    and not hides_status(u.user_id)
    and rating_of(u.user_id, auth.uid()) > 0;
$$;
revoke all on function public.friends_usual_times() from public, anon;
grant execute on function public.friends_usual_times() to authenticated;

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 76 $$;

insert into public.drivetalk_migrations (name)
values ('20261076000000_usual_times') on conflict do nothing;

notify pgrst, 'reload schema';
