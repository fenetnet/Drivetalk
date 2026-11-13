-- DriveBond — the phone tells the owner when Android blocked a trip
-- (owner, 2026-11-12, D-175: "if it happened to me, it can happen to others").
--
-- When Android refuses to run the trip service (a daily time limit,
-- battery saving…) or stops it mid-trip, the phone's background part
-- sends one short note with Android's own reason, the Android version and
-- the battery setting. It lands with the crash notes in the owner's
-- "Numbers" screen, with the sender's name — nothing about places or
-- calls. At most 20 a day per person (like crash notes). App 1.3.4;
-- older apps: nothing changes.

create or replace function public.device_report(p_token text, p_kind text, p_message text)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
begin
  if me is null then return false; end if;
  if p_kind is null or p_kind !~ '^[a-z_]{3,40}$' then return false; end if;
  if (select count(*) from crash_reports
      where user_id = me and created_at > now() - interval '1 day') >= 20 then
    return false;
  end if;
  insert into crash_reports (user_id, build, kind, message)
  values (me, 'android service', p_kind, left(coalesce(p_message, ''), 500));
  return true;
end;
$$;
revoke all on function public.device_report(text, text, text) from public;
grant execute on function public.device_report(text, text, text) to anon, authenticated;

-- Last: the version says 82 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 82 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261082000000_trip_blocked_reports') on conflict do nothing;

notify pgrst, 'reload schema';
