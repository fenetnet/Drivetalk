-- DriveBond — less work while people drive (owner, 2026-11-09, D-173:
-- "what else can be made lighter, maybe in the morning").
--
-- While driving, every phone renews its trip every 4 minutes. Two things
-- in that renewal caused work for nothing (same result for everyone):
--
-- 1. "Available to certain groups": each renewal deleted the whole hidden
--    member list and wrote it again — every friend a delete and an insert,
--    each one sent as a live change to the phones. Now only real
--    differences are written (usually none).
-- 2. A renewal of an automatic trip only moves its end time, which friends
--    don't see (a trip's end isn't known): it no longer rings the friends'
--    phones (server 78). Anything they do see — mode, a call, the groups,
--    a new trip — still rings at once.
--
-- Older apps: nothing changes.

create or replace function public.rebuild_audience(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  aud uuid;
  ids uuid[];
  exc boolean;
  want uuid[];
begin
  select audience_circle, audience_ids, audience_except into aud, ids, exc
  from profiles where id = p_user;
  if aud is null or ids is null then return; end if;
  select coalesce(array_agg(distinct x.f), '{}') into want from (
    select m.member as f from circle_members m
    join circles c on c.id = m.circle_id and c.owner = p_user and not c.hidden
    where not exc and m.circle_id = any(ids)
    union all
    select f from friend_ids(p_user) f
    where exc
      and not exists (select 1 from circle_members m
                      join circles c on c.id = m.circle_id and c.owner = p_user
                      where m.circle_id = any(ids) and m.member = f)) x
  where are_connected(p_user, x.f);
  -- Only the differences.
  delete from circle_members where circle_id = aud and not (member = any(want));
  insert into circle_members (circle_id, member)
  select aud, f from unnest(want) f
  on conflict do nothing;
end;
$$;
revoke all on function public.rebuild_audience(uuid) from public, anon, authenticated;

create or replace function private.ring_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  r record := coalesce(new, old);
  who uuid[];
begin
  begin
    -- An automatic trip's renewal (only its unseen end moved): no ring.
    if tg_table_name = 'availability' and tg_op = 'UPDATE'
       and new.source = 'auto' and old.source = 'auto'
       and new.mode = old.mode
       and new.started_at is not distinct from old.started_at
       and new.circle_id is not distinct from old.circle_id
       and new.call_until is not distinct from old.call_until
       and new.phone_until is not distinct from old.phone_until
       and new.missed_at is not distinct from old.missed_at
       and new.quiet_until is not distinct from old.quiet_until then
      return null;
    end if;
    case tg_table_name
      when 'availability' then
        who := array[r.user_id] || array(select friend_ids(r.user_id));
      when 'match_offers', 'connections' then
        who := array[r.user_a, r.user_b];
      when 'connect_requests' then
        who := array[r.from_user, r.to_user];
      when 'circles' then
        who := array[r.owner]
               || array(select m.member from circle_members m where m.circle_id = r.id);
      when 'circle_members' then
        who := array[r.member]
               || array(select c.owner from circles c where c.id = r.circle_id);
      else
        who := '{}';
    end case;
    perform private.ring(who);
  exception when others then null;
  end;
  return null;
end;
$$;
revoke all on function private.ring_change() from public, anon, authenticated;

-- Last: the version says 79 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 79 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261079000000_quiet_renewals') on conflict do nothing;
