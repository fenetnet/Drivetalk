-- DriveBond — "did anything change?" (owner, 2026-11-10, D-173; app 1.3.3).
--
-- The free plan's monthly traffic (egress) was filling up: every refresh
-- sent everything again, even when nothing had changed (e.g. every 2
-- minutes in a pocket). Now the app sends a short fingerprint of what it
-- already has; if the answer would be the same, the server says only
-- "same" (a few bytes) instead of sending it all again. The app shows
-- exactly the same thing. Anything new → the full answer, as before.
--
-- A separate name (not a second app_snapshot), so app 1.3.2 keeps calling
-- app_snapshot() exactly as it does. Older apps: nothing changes.

create or replace function public.app_snapshot_if_changed(p_hash text default null)
returns jsonb language plpgsql stable set search_path = public as $$
declare
  j jsonb := app_snapshot();
  h text := md5(j::text);
begin
  if p_hash is not null and p_hash = h then
    return jsonb_build_object('same', true, 'hash', h);
  end if;
  return j || jsonb_build_object('hash', h);
end;
$$;
revoke all on function public.app_snapshot_if_changed(text) from public, anon;
grant execute on function public.app_snapshot_if_changed(text) to authenticated;

-- Last: the version says 80 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 80 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261080000000_snapshot_if_changed') on conflict do nothing;

notify pgrst, 'reload schema';
