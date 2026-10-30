-- DriveBond — notifications don't pile up (privacy policy, 2026-10-18).
-- Every night, besides the earlier cleanup:
-- - the notification queue (names in "X is on the way" / "X tried to reach
--   you"): after 2 days;
-- - "already told today" marks: after 2 days;
-- - a phone's push address unused for 180 days (the app renews it on every
--   start), and "this phone heard about version N" marks after 30 days.

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
end;
$$;
revoke all on function public.nightly_cleanup() from public, anon, authenticated;

-- Last: the version says 49 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 49 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261049000000_push_cleanup') on conflict do nothing;
