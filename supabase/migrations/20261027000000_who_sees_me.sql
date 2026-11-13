-- DriveBond — "Who sees that I'm free" (D-095).
--
-- Each of my circles (family, friends, work, my own) has a rule: always /
-- never / only in some modes (driving, walking, break, free). People in no
-- circle follow the "everyone else" rule. Someone in two circles sees me only
-- if BOTH allow it (the safer side wins).
--
-- Whoever doesn't see me is also never offered to talk with me (an offer
-- would tell them I'm free). They are not told anything: to them I'm simply
-- not free right now.
--
-- Also: no offer between two people when neither has a phone number (the
-- call couldn't happen); "I'd like to talk" (the heart) is gone from the app,
-- so its leftovers no longer change the order quietly.

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 27 $$;
grant execute on function public.schema_version() to anon, authenticated;

-- 1. the rules ---------------------------------------------------------------
-- null = always; {} = never; {driving, free} = only in those modes.
alter table public.circles add column if not exists show_modes text[];
do $$
begin
  alter table public.circles add constraint circles_show_modes_check
    check (show_modes is null or show_modes <@ array['driving', 'walking', 'breakTime', 'free']);
exception when duplicate_object then null;
end;
$$;

-- "Everyone else" (friends in none of my circles). No row = always.
create table if not exists public.others_visibility (
  user_id uuid primary key references public.profiles (id) on delete cascade default auth.uid(),
  show_modes text[] check (show_modes is null or show_modes <@ array['driving', 'walking', 'breakTime', 'free']),
  updated_at timestamptz not null default now()
);
alter table public.others_visibility enable row level security;
drop policy if exists others_visibility_own on public.others_visibility;
create policy others_visibility_own on public.others_visibility for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke all on public.others_visibility from anon;
grant select, insert, update, delete on public.others_visibility to authenticated;

-- 2. the check (internal: nobody may ask it about someone else's rules) ------
create or replace function public.can_see(p_viewer uuid, p_owner uuid, p_mode text)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when exists (
      select 1 from circles c join circle_members m on m.circle_id = c.id
      where c.owner = p_owner and m.member = p_viewer)
    then not exists (
      select 1 from circles c join circle_members m on m.circle_id = c.id
      where c.owner = p_owner and m.member = p_viewer
        and c.show_modes is not null and not (p_mode = any (c.show_modes)))
    else coalesce((
      select o.show_modes is null or p_mode = any (o.show_modes)
      from others_visibility o where o.user_id = p_owner), true)
  end;
$$;
revoke all on function public.can_see(uuid, uuid, text) from public, anon, authenticated;

-- For the availability policy: "may I see this person's free status right
-- now?" Answers only about their CURRENT availability, so asking it tells
-- nothing beyond what the list itself shows (no rules can be probed).
create or replace function public.sees_availability(p_owner uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from availability a
    where a.user_id = p_owner and a.expires_at > now()
      and can_see(auth.uid(), p_owner, a.mode));
$$;
revoke all on function public.sees_availability(uuid) from public, anon;
grant execute on function public.sees_availability(uuid) to authenticated;

drop policy if exists availability_select on public.availability;
create policy availability_select on public.availability for select to authenticated
  using (
    user_id = auth.uid()
    or (expires_at > now()
        and public.are_connected(auth.uid(), user_id)
        and not public.is_blocked_between(auth.uid(), user_id)
        and public.in_audience(circle_id, auth.uid())
        and not public.hides_status(user_id)
        and not public.hides_status(auth.uid())
        and public.sees_availability(user_id))
  );

-- 3. "hide my status" (older app) becomes "everyone: never" ------------------
insert into public.others_visibility (user_id, show_modes)
select id, '{}' from public.profiles where hide_status
on conflict (user_id) do update set show_modes = '{}', updated_at = now();
update public.circles c set show_modes = '{}'
from public.profiles p where p.id = c.owner and p.hide_status;
update public.profiles set hide_status = false where hide_status;

-- 4. ready-made circles (family, friends, work), once per person -------------
alter table public.profiles add column if not exists presets_done boolean not null default false;

create or replace function public.ensure_preset_circles(p_names text[])
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  n text;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if coalesce((select presets_done from profiles where id = me), true) then return; end if;
  foreach n in array coalesce(p_names[1:5], '{}') loop
    n := btrim(n);
    if char_length(n) between 1 and 30
       and not exists (select 1 from circles where owner = me and name = n) then
      insert into circles (owner, name) values (me, n);
    end if;
  end loop;
  update profiles set presets_done = true where id = me;
end;
$$;
revoke all on function public.ensure_preset_circles(text[]) from public, anon;
grant execute on function public.ensure_preset_circles(text[]) to authenticated;

-- 5. the heart is gone: its leftovers no longer reorder offers ---------------
delete from public.talk_intents;

-- 6. offers: only between people who see each other, and only when a call
--    can happen (at least one of them has a number) -------------------------
create or replace function public.create_offers_for(p_user uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare
  mine availability;
  other record;
  lo uuid;
  hi uuid;
  quick boolean;
begin
  -- One at a time across everyone: no two offers race for the same person.
  perform pg_advisory_xact_lock(727274);
  -- A question nobody answered in time is over (its quiet minutes count
  -- from when it ran out).
  update match_offers set status = 'expired', updated_at = expires_at
  where status = 'pending' and expires_at <= now();
  select * into mine from availability where user_id = p_user and expires_at > now();
  if not found then return 0; end if;
  if has_open_offer(p_user) or in_call(p_user) or on_phone(p_user) then return 0; end if;
  -- A quiet gap: after a question that didn't become a call (no / no
  -- answer / cancelled), nothing new for me for 5 minutes.
  if quiet_gap(p_user) or asked_enough(p_user, mine.started_at) then return 0; end if;

  for other in
    select a.user_id, a.expires_at, a.circle_id, a.started_at, a.mode,
           -- Only real talks (someone said "we talked"), not just two yeses.
           (select max(o.accepted_at) from match_offers o
            where o.status = 'accepted' and o.talked
              and o.user_a = least(p_user, a.user_id)
              and o.user_b = greatest(p_user, a.user_id)) as last_talk
    from availability a
    join connections c
      on (c.user_a = p_user and c.user_b = a.user_id)
      or (c.user_b = p_user and c.user_a = a.user_id)
    where a.expires_at > now()
      and not is_blocked_between(p_user, a.user_id)
      -- 0 on either side = never offered.
      and rating_of(p_user, a.user_id) > 0
      and rating_of(a.user_id, p_user) > 0
      -- "Not soon" after a call (either side asked): not offered for a while.
      and not exists (
        select 1 from pair_snoozes z
        where z.until > now()
          and ((z.from_user = p_user and z.to_user = a.user_id)
               or (z.from_user = a.user_id and z.to_user = p_user)))
    -- Quietly: quick-connect friends first, then how much both want to
    -- talk, then whoever I talked with least recently.
    order by (is_quick(p_user, a.user_id) and is_quick(a.user_id, p_user)) desc,
             -- how much both want to talk (0–5 each, 3 when not set)
             rating_of(p_user, a.user_id) + rating_of(a.user_id, p_user) desc,
             last_talk asc nulls first,
             random()
  loop
    if not in_audience(mine.circle_id, other.user_id)
       or not in_audience(other.circle_id, p_user)
       -- "Who sees that I'm free": both must see each other.
       or not can_see(other.user_id, p_user, mine.mode)
       or not can_see(p_user, other.user_id, other.mode)
       -- Nobody could dial: no question that can't become a call.
       or not exists (select 1 from phone_numbers n where n.user_id in (p_user, other.user_id))
       or has_open_offer(other.user_id)
       or in_call(other.user_id)
       or on_phone(other.user_id)
       or quiet_gap(other.user_id)
       or asked_enough(other.user_id, other.started_at) then
      continue;
    end if;
    lo := least(p_user, other.user_id);
    hi := greatest(p_user, other.user_id);
    if exists (
      select 1 from match_offers o
      where o.user_a = lo and o.user_b = hi
        and ((o.status = 'declined' and o.updated_at > now() - interval '2 minutes')
             -- after a call: not the same pair again for 30 minutes
             or (o.status = 'accepted' and o.accepted_at > now() - interval '30 minutes')
             -- once per trip / free window: a pair that already got a
             -- question (and didn't talk) isn't asked again until one of
             -- them starts a new window
             or (o.status in ('declined', 'expired', 'cancelled')
                 and o.created_at >= greatest(mine.started_at, other.started_at)))
    ) then
      continue;
    end if;
    quick := is_quick(p_user, other.user_id) and is_quick(other.user_id, p_user)
      -- once a day per pair
      and not exists (
        select 1 from match_offers o
        where o.user_a = lo and o.user_b = hi and o.quick
          and o.created_at > now() - interval '1 day')
      -- once per availability window, for each of them
      and not exists (
        select 1 from match_offers o
        where o.quick and p_user in (o.user_a, o.user_b) and o.created_at >= mine.started_at)
      and not exists (
        select 1 from match_offers o
        where o.quick and other.user_id in (o.user_a, o.user_b) and o.created_at >= other.started_at);
    if quick then
      -- Agreed in advance, but nobody may dial before both had 5 seconds to
      -- cancel (not_before is set when both phones have seen it).
      insert into match_offers (user_a, user_b, expires_at, status, a_response, b_response,
                                quick, accepted_at)
      values (lo, hi, least(mine.expires_at, other.expires_at), 'accepted', 'accept', 'accept',
              true, now());
    else
      -- A question waits 2 minutes for answers, then it's over.
      insert into match_offers (user_a, user_b, expires_at)
      values (lo, hi, least(mine.expires_at, other.expires_at, now() + interval '2 minutes'))
      on conflict do nothing;
    end if;
    return 1;
  end loop;
  return 0;
end;
$$;
revoke all on function public.create_offers_for(uuid) from public, anon, authenticated;

-- 7. deleting my account also deletes my "everyone else" rule (cascade) ------

insert into public.drivetalk_migrations (name)
values ('20261027000000_who_sees_me') on conflict do nothing;
