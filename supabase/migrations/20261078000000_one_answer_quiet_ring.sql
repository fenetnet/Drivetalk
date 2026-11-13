-- DriveBond — a lighter load on the small free server, part 2 (owner,
-- 2026-11-09, D-173 stage 2). For app 1.3.2; older apps: nothing changes.
--
-- 1. One answer instead of ~20: app_snapshot() returns, in one request,
--    exactly what the app used to ask in ~20 separate requests. It runs as
--    the user (not security definer), so every privacy rule applies just
--    as before. The app falls back to the old way if it fails.
-- 2. A quiet "ring" instead of the full change: when something changes,
--    the server itself sends an empty internal signal ("something new for
--    you") only to the people it concerns, on their private channel
--    u:<their id>. Nothing is shown to anyone and there is no data in it;
--    the app simply refreshes. Realtime no longer has to check every
--    change against every connected phone. Only the person themselves can
--    listen to their channel. ring_me() lets the app check that the ring
--    really arrives; if not, it goes back to the old way.
--    The old live updates stay on for older apps (removed only after
--    everyone has updated — two steps, as the rules say).

-- ------------------------------------------------------- 1. one answer

create or replace function public.app_snapshot()
returns jsonb language plpgsql stable set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  return jsonb_build_object(
    'profiles', (select coalesce(jsonb_agg(to_jsonb(x)), '[]') from (
      select id, display_name, gender, photo_version from profiles) x),
    'availability', (select coalesce(jsonb_agg(to_jsonb(x)), '[]') from (
      select user_id, mode, expires_at, source, call_until, phone_until,
             missed_at, quiet_until
      from availability) x),
    'offers', (select coalesce(jsonb_agg(to_jsonb(x) order by x.updated_at desc), '[]') from (
      select * from match_offers
      where updated_at > now() - interval '12 hours'
      order by updated_at desc limit 50) x),
    'talks', (select coalesce(jsonb_agg(to_jsonb(x) order by x.updated_at desc), '[]') from (
      select user_a, user_b, updated_at from match_offers
      where status = 'accepted' and talked
      order by updated_at desc limit 300) x),
    'intents', (select coalesce(jsonb_agg(to_jsonb(x)), '[]') from (
      select to_user, expires_at from talk_intents) x),
    'circles', (select coalesce(jsonb_agg(to_jsonb(x)), '[]') from (
      select c.id, c.name, c.quick, c.show_modes,
             (select coalesce(jsonb_agg(jsonb_build_object('member', m.member)), '[]')
              from circle_members m where m.circle_id = c.id) as circle_members
      from circles c) x),
    'ratings', (select coalesce(jsonb_agg(to_jsonb(x)), '[]') from (
      select friend, rating from friend_ratings) x),
    'activity', (select coalesce(jsonb_agg(to_jsonb(x)), '[]') from friends_activity() x),
    'hide', (select coalesce(jsonb_agg(to_jsonb(x)), '[]') from (
      select hide_status from profiles where id = me) x),
    'others', (select coalesce(jsonb_agg(to_jsonb(x)), '[]') from (
      select show_modes from others_visibility) x),
    'askable', (select coalesce(jsonb_agg(x), '[]') from askable_friends() x),
    'status', my_status(),
    'quick', (select coalesce(jsonb_agg(to_jsonb(x)), '[]') from quick_status() x),
    'pauses', (select coalesce(jsonb_agg(to_jsonb(x)), '[]') from my_pauses() x),
    'mine', (select coalesce(jsonb_agg(to_jsonb(x)), '[]') from my_availability_details() x),
    'auto_yes', auto_yes_status(),
    'usual', (select coalesce(jsonb_agg(to_jsonb(x)), '[]') from friends_usual_times() x)
  );
end;
$$;
revoke all on function public.app_snapshot() from public, anon;
grant execute on function public.app_snapshot() to authenticated;

-- ------------------------------------------------------- 2. quiet ring

-- Ring these people (once per transaction each). Never fails the change
-- that caused it.
create or replace function private.ring(p_users uuid[])
returns void language plpgsql security definer set search_path = public as $$
declare
  u uuid;
  k text;
begin
  foreach u in array coalesce(p_users, '{}') loop
    continue when u is null;
    k := 'drivetalk.rung_' || replace(u::text, '-', '');
    continue when current_setting(k, true) = '1';
    perform set_config(k, '1', true);
    begin
      perform realtime.send('{}'::jsonb, 'ping', 'u:' || u::text, true);
    exception when others then null;
    end;
  end loop;
exception when others then null;
end;
$$;
revoke all on function private.ring(uuid[]) from public, anon, authenticated;

create or replace function private.ring_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  r record := coalesce(new, old);
  who uuid[];
begin
  begin
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

do $$
declare
  t text;
begin
  foreach t in array array['availability', 'match_offers', 'connections',
                           'connect_requests', 'circles', 'circle_members'] loop
    execute format('drop trigger if exists ring_change on public.%I', t);
    execute format('create trigger ring_change after insert or update or delete '
                   'on public.%I for each row execute function private.ring_change()', t);
  end loop;
end;
$$;

-- Only I may listen to my own channel (private Realtime channel u:<me>).
do $$
begin
  if to_regclass('realtime.messages') is not null then
    drop policy if exists drivetalk_own_ring on realtime.messages;
    create policy drivetalk_own_ring on realtime.messages
      for select to authenticated
      using (realtime.topic() = 'u:' || auth.uid()::text);
  end if;
exception when others then
  raise notice 'realtime not available: %', sqlerrm;
end;
$$;

-- The app's check that the ring arrives: ring me now.
create or replace function public.ring_me()
returns boolean language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  perform realtime.send('{}'::jsonb, 'ping', 'u:' || me::text, true);
  return true;
exception when others then
  return false;
end;
$$;
revoke all on function public.ring_me() from public, anon;
grant execute on function public.ring_me() to authenticated;

-- Last: the version says 78 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 78 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261078000000_one_answer_quiet_ring') on conflict do nothing;

notify pgrst, 'reload schema';
