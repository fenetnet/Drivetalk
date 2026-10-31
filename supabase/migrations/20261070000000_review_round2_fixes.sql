-- DriveBond — fixes from the adversarial check of 68/69 (D-164).
--
-- 1. "Waiting for approval" survives remove → restore and block → unblock
--    (both were a way around the approval added in 68).
-- 2. "Available to…": the per-row triggers of 69 were far too slow for big
--    friend lists (seconds per change, timeouts). Now one rebuild per
--    statement and owner for group changes; new friends are picked up at
--    the next start (manual windows rebuild on start, trips in auto_start).
--    Deleting a chosen group takes it out of the choice (before: trips
--    became visible to nobody).
-- 3. Contact searches: one at a time per account (the daily count can't
--    be raced). Usage events: an index for the hourly count.
-- 4. "Connects at once": nothing for a viewer who is anonymous themselves.
-- Older apps: same functions and answers.

-- ------------------------------------------------------------ 1. approval kept

alter table public.removed_pairs add column if not exists pending_for uuid;
alter table public.blocks add column if not exists pending_for uuid;

create or replace function public.remember_removed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    delete from circle_members m using circles c
    where m.circle_id = c.id
      and ((c.owner = old.user_a and m.member = old.user_b)
           or (c.owner = old.user_b and m.member = old.user_a));
    -- Open questions between the two end now (and a quick connect that
    -- hasn't started).
    update match_offers set status = 'cancelled', updated_at = now()
    where user_a = least(old.user_a, old.user_b) and user_b = greatest(old.user_a, old.user_b)
      and (status = 'pending' or (status = 'accepted' and quick and caller is null));
    if exists (select 1 from profiles where id = old.user_a)
       and exists (select 1 from profiles where id = old.user_b) then
      -- Who still had to approve is remembered (D-164).
      insert into removed_pairs (user_a, user_b, removed_by, pending_for)
      values (old.user_a, old.user_b, auth.uid(), old.pending_for)
      on conflict (user_a, user_b) do update set removed_by = excluded.removed_by,
                                                 pending_for = excluded.pending_for,
                                                 created_at = now();
    end if;
    return old;
  end if;
  delete from removed_pairs where user_a = new.user_a and user_b = new.user_b;
  return new;
end;
$$;

create or replace function public.restore_friend(p_user uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  waiting uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select r.pending_for into waiting from removed_pairs r
  where r.user_a = least(me, p_user) and r.user_b = greatest(me, p_user)
    and (r.removed_by = me or r.removed_by is null);
  if not found or is_blocked_between(me, p_user) then
    return false;
  end if;
  -- Back as it was: if they hadn't approved me yet, they still decide.
  insert into connections (user_a, user_b, pending_for)
  values (least(me, p_user), greatest(me, p_user),
          case when waiting = p_user then p_user end)
  on conflict do nothing;
  perform create_offers_for(me);
  return true;
end;
$$;

create or replace function public.block_user(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  had boolean;
  waiting uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_user = me then return; end if;
  -- Only someone I'm (or was) connected with or got an offer with: blocking
  -- a random id must not reveal their name (my_blocks).
  if not (are_connected(me, p_user) or was_removed(me, p_user)
          or exists (select 1 from match_offers
                     where user_a = least(me, p_user) and user_b = greatest(me, p_user))) then
    return;
  end if;
  had := are_connected(me, p_user);
  select c.pending_for into waiting from connections c
  where c.user_a = least(me, p_user) and c.user_b = greatest(me, p_user);
  insert into blocks (blocker, blocked, was_connected, pending_for)
  values (me, p_user, had, waiting)
  on conflict (blocker, blocked) do nothing;
  delete from connections where user_a = least(me, p_user) and user_b = greatest(me, p_user);
  delete from circle_members m using circles c
  where m.circle_id = c.id and c.owner = me and m.member = p_user;
  update match_offers set status = 'cancelled', updated_at = now()
  where status = 'pending' and user_a = least(me, p_user) and user_b = greatest(me, p_user);
end;
$$;

create or replace function public.unblock_user(p_user uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  b blocks;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  delete from blocks where blocker = me and blocked = p_user returning * into b;
  if not found then return 'not_blocked'; end if;
  if b.was_connected and not is_blocked_between(me, p_user) then
    -- Back as it was: if they hadn't approved me yet, they still decide.
    insert into connections (user_a, user_b, pending_for)
    values (least(me, p_user), greatest(me, p_user),
            case when b.pending_for = p_user then p_user end)
    on conflict do nothing;
    return 'reconnected';
  end if;
  return 'unblocked';
end;
$$;

-- ------------------------------------------------------------ 2. audience

drop trigger if exists audience_follow_members on public.circle_members;
drop trigger if exists audience_follow_friends on public.connections;
drop function if exists public.audience_follow_members();
drop function if exists public.audience_follow_friends();

-- Once per statement and owner (the app replaces a group's members in
-- one go): rebuilds only owners whose choice includes that group.
create or replace function public.audience_follow_rows()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  o uuid;
begin
  if pg_trigger_depth() > 1 then return null; end if;
  for o in
    select distinct c.owner
    from (select circle_id from changed) x
    join circles c on c.id = x.circle_id and not c.hidden
    join profiles p on p.id = c.owner
    where p.audience_circle is not null
      and (p.audience_except or c.id = any(coalesce(p.audience_ids, '{}')))
  loop
    perform rebuild_audience(o);
  end loop;
  return null;
end;
$$;
revoke all on function public.audience_follow_rows() from public, anon, authenticated;

drop trigger if exists audience_after_insert on public.circle_members;
create trigger audience_after_insert
  after insert on public.circle_members
  referencing new table as changed
  for each statement execute function public.audience_follow_rows();
drop trigger if exists audience_after_delete on public.circle_members;
create trigger audience_after_delete
  after delete on public.circle_members
  referencing old table as changed
  for each statement execute function public.audience_follow_rows();

-- A chosen group deleted: out of the choice ("only…" with nothing left =
-- everyone again), and the audience rebuilt without it.
create or replace function public.circle_deleted()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  p profiles;
begin
  delete from availability where circle_id = old.id;
  if old.hidden then return old; end if;
  select * into p from profiles
  where id = old.owner and old.id = any(coalesce(audience_ids, '{}'));
  if not found then return old; end if;
  update profiles set audience_ids = array_remove(audience_ids, old.id)
  where id = old.owner;
  if cardinality(array_remove(p.audience_ids, old.id)) = 0 and not p.audience_except then
    update profiles set audience_circle = null, audience_ids = null where id = old.owner;
    update availability set circle_id = null
    where user_id = old.owner and circle_id = p.audience_circle;
  else
    perform rebuild_audience(old.owner);
  end if;
  return old;
end;
$$;

-- ------------------------------------------------------------ 3. searches, events

create or replace function public.find_friends(p_hashes text[])
returns table (user_id uuid, display_name text, hash text, is_friend boolean)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  n integer := coalesce(array_length(p_hashes, 1), 0);
begin
  if me is null then raise exception 'not_authenticated'; end if;
  -- One search at a time per account: the daily count can't be raced.
  perform pg_advisory_xact_lock(hashtext('find_friends'), hashtext(me::text));
  if (select count(*) from contact_searches cs
      where cs.user_id = me and cs.at > now() - interval '1 day') >= 30 then
    raise exception 'rate_limited';
  end if;
  if n > 5000 then raise exception 'too_many_contacts'; end if;
  if coalesce((select sum(c.n) from contact_search_counts c
               where c.user_id = me and c.at > now() - interval '1 day'), 0) + n > 20000 then
    raise exception 'rate_limited';
  end if;
  insert into contact_searches (user_id) values (me);
  insert into contact_search_counts (user_id, n) values (me, n);
  delete from contact_hashes where owner = me;
  if n = 0 then return; end if;
  insert into contact_hashes (owner, hash)
  select distinct me, h from unnest(p_hashes) as h
  where h ~ '^[0-9a-f]{64}$'
    and exists (select 1 from phone_numbers pn where pn.phone_hash = h and pn.user_id <> me)
  on conflict do nothing;

  -- Waiting for me, and I have their number: approved — unless another
  -- account claims that number too (then I choose on their card).
  update connections c set pending_for = null
  where c.pending_for = me
    and number_unique(case when c.user_a = me then c.user_b else c.user_a end)
    and exists (
      select 1 from phone_numbers pn
      join contact_hashes h on h.hash = pn.phone_hash and h.owner = me
      where pn.user_id = case when c.user_a = me then c.user_b else c.user_a end);

  return query
    select x.user_id, x.display_name, x.phone_hash, x.is_friend
    from (
      select distinct on (pn.phone_hash)
             pn.user_id, pr.display_name, pn.phone_hash,
             are_connected(me, pn.user_id) as is_friend
      from phone_numbers pn
      join profiles pr on pr.id = pn.user_id
      where pn.user_id <> me
        and pn.phone_hash in (select c.hash from contact_hashes c where c.owner = me)
        and not blocked_any(me, pn.user_id)
      order by pn.phone_hash,
               replaced_account(pn.user_id) asc,
               are_connected(me, pn.user_id) desc,
               pr.last_seen_at desc
    ) x
    where x.is_friend or not kept_apart(me, x.user_id)
    order by x.display_name;
end;
$$;

create index if not exists app_events_user_created
  on public.app_events (user_id, created_at);

-- ------------------------------------------------------------ 4. ⚡ status

create or replace function public.auto_yes_status()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  return jsonb_build_object(
    'on', (select auto_yes from profiles where id = me),
    'min', (select auto_yes_min from profiles where id = me),
    'instant', coalesce((
      select jsonb_agg(a.user_id)
      from connections c
      join availability a
        on a.user_id = case when c.user_a = me then c.user_b else c.user_a end
      join profiles p on p.id = a.user_id and p.auto_yes
      where me in (c.user_a, c.user_b) and c.pending_for is null
        and not is_anonymous(me)
        and a.mode = 'driving' and a.expires_at > now()
        -- Only friends I may see as free right now (D-164).
        and not hides_status(a.user_id)
        and not is_anonymous(a.user_id)
        and sees_free_apart_from_name(me, a)
        -- The first minutes of a trip a tap gets "busy": no ring then.
        and (a.quiet_until is null or a.quiet_until <= now())
        and auto_yes_for(a.user_id, me)), '[]'::jsonb));
end;
$$;

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 70 $$;

insert into public.drivetalk_migrations (name)
values ('20261070000000_review_round2_fixes') on conflict do nothing;

notify pgrst, 'reload schema';
