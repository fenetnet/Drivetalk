-- DriveBond — "removed" stays per account again (D-141, fixes D-134).
--
-- D-134 made a removal count across every account of the same number
-- (reinstalls). But a removal is often of a stale duplicate (an old account
-- of someone who reinstalled), or an old test — and then the person's
-- CURRENT account could never be found or added again (owner: his wife
-- couldn't find him in her contacts). Now, as before D-134: a removal is
-- between those two accounts only. A BLOCK still covers every account of
-- the number (that one is meant to stick).

create or replace function public.kept_apart(me uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select blocked_any(me, p_user) or was_removed(me, p_user);
$$;
revoke all on function public.kept_apart(uuid, uuid) from public, anon, authenticated;

-- Last: the version says 58 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 58 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261058000000_removed_per_account') on conflict do nothing;
