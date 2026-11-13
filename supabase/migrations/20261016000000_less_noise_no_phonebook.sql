-- DriveTalk — even fewer questions, and no phone book kept (D-072).
--
--   * A question ("X is free — talk?") waits 2 minutes, then it's over.
--   * After 3 questions that didn't become a call in one free window / trip,
--     no more questions in that window (the person is probably busy).
--   * Contacts: the server keeps ONLY the hashes that belong to DriveTalk
--     users (needed to see "each saved the other"). Numbers of people who
--     don't use DriveTalk are not kept at all; old ones are removed now.

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 16 $$;
grant execute on function public.schema_version() to anon, authenticated;

-- Has this user had 3 questions without a call since their window began?
create or replace function public.asked_enough(p_user uuid, p_since timestamptz)
returns boolean language sql stable security definer set search_path = public as $$
  select count(*) >= 3 from match_offers o
  where p_user in (o.user_a, o.user_b)
    and not o.quick
    and o.created_at >= p_since
    and o.status in ('declined', 'expired', 'cancelled');
$$;
revoke all on function public.asked_enough(uuid, timestamptz) from public, anon, authenticated;

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
  if has_open_offer(p_user) or in_call(p_user) then return 0; end if;
  -- A quiet gap: after a question that didn't become a call (no / no
  -- answer / cancelled), nothing new for me for 5 minutes.
  if quiet_gap(p_user) or asked_enough(p_user, mine.started_at) then return 0; end if;

  for other in
    select a.user_id, a.expires_at, a.circle_id, a.started_at,
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
      -- "Not soon" after a call (either side asked): not offered for a while.
      and not exists (
        select 1 from pair_snoozes z
        where z.until > now()
          and ((z.from_user = p_user and z.to_user = a.user_id)
               or (z.from_user = a.user_id and z.to_user = p_user)))
    -- Quietly: quick-connect friends first, then "I'd like to talk"
    -- (either side), then whoever I talked with least recently.
    order by (is_quick(p_user, a.user_id) and is_quick(a.user_id, p_user)) desc,
             wants_to_talk(p_user, a.user_id) desc,
             last_talk asc nulls first,
             random()
  loop
    if not in_audience(mine.circle_id, other.user_id)
       or not in_audience(other.circle_id, p_user)
       or has_open_offer(other.user_id)
       or in_call(other.user_id)
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

create or replace function public.find_friends(p_hashes text[])
returns table (display_name text, kind text)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  my_hash text;
  other record;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_hashes is null or array_length(p_hashes, 1) is null then
    delete from contact_hashes where owner = me;
    return;
  end if;
  if array_length(p_hashes, 1) > 5000 then raise exception 'too_many_contacts'; end if;
  delete from contact_hashes where owner = me;
  -- Keep only numbers of people who use DriveTalk (the rest is dropped
  -- right here and never stored).
  insert into contact_hashes (owner, hash)
  select distinct me, h from unnest(p_hashes) as h
  where h ~ '^[0-9a-f]{64}$'
    and exists (select 1 from phone_numbers pn where pn.phone_hash = h and pn.user_id <> me)
  on conflict do nothing;

  select phone_hash into my_hash from phone_numbers where user_id = me;

  for other in
    select pn.user_id, pr.display_name,
           (my_hash is not null and exists (
              select 1 from contact_hashes c
              where c.owner = pn.user_id and c.hash = my_hash)) as has_me,
           exists (select 1 from connect_requests r
                   where r.from_user = pn.user_id and r.to_user = me
                     and r.status = 'pending') as asked_me,
           exists (select 1 from connect_requests r
                   where r.from_user = me and r.to_user = pn.user_id) as i_asked
    from phone_numbers pn
    join profiles pr on pr.id = pn.user_id
    where pn.user_id <> me
      and pn.phone_hash in (select hash from contact_hashes where owner = me)
      and not is_blocked_between(me, pn.user_id)
      and not are_connected(me, pn.user_id)
  loop
    if other.has_me or other.asked_me then
      -- Both saved each other, or they asked for me and I have them.
      insert into connections (user_a, user_b)
      values (least(me, other.user_id), greatest(me, other.user_id))
      on conflict do nothing;
      update connect_requests set status = 'accepted', updated_at = now()
      where status = 'pending'
        and ((from_user = me and to_user = other.user_id)
             or (from_user = other.user_id and to_user = me));
      display_name := other.display_name;
      kind := 'connected';
      return next;
    elsif not other.i_asked then
      -- Asked once per pair (a "no" is never asked again).
      insert into connect_requests (from_user, to_user)
      values (me, other.user_id)
      on conflict do nothing;
      display_name := other.display_name;
      kind := 'requested';
      return next;
    end if;
  end loop;
  perform create_offers_for(me);
end;
$$;
revoke all on function public.find_friends(text[]) from public, anon;
grant execute on function public.find_friends(text[]) to authenticated;

-- Remove what was kept before: hashes that are not a DriveTalk user's number.
delete from public.contact_hashes c
where not exists (select 1 from public.phone_numbers pn where pn.phone_hash = c.hash);

insert into public.drivetalk_migrations (name)
values ('20261016000000_less_noise_no_phonebook') on conflict do nothing;
