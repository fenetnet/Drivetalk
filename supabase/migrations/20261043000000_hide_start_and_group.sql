-- DriveBond — friends no longer receive when I started or for which group
-- my free time is (D-118).
--
-- A friend's phone used to receive my whole availability row. The app
-- never showed started_at or circle_id about others, but someone reading
-- the server directly could. Now friends can read only what the app shows:
-- free, the mode, until when, automatic or not, in a call, the quiet first
-- minutes. My own start time and group come from my_availability_details().

revoke select on public.availability from authenticated;
grant select (user_id, mode, expires_at, source, call_until, phone_until,
              missed_at, quiet_until)
  on public.availability to authenticated;

create or replace function public.my_availability_details()
returns table (started_at timestamptz, circle_id uuid)
language sql stable security definer set search_path = public as $$
  select a.started_at, a.circle_id from availability a where a.user_id = auth.uid();
$$;
revoke all on function public.my_availability_details() from public, anon;
grant execute on function public.my_availability_details() to authenticated;

-- Last: the version says 43 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 43 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261043000000_hide_start_and_group') on conflict do nothing;
