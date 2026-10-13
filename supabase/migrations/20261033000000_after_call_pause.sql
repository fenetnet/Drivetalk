-- DriveBond — after a call: "when to suggest X again?" (D-108).
--
-- - Every call (both said yes) counts as a talk right away; "we didn't
--   manage to talk" takes it back.
-- - After a call, the pair isn't suggested automatically for 3 days.
--   Each side may change it after the call: any time / tomorrow / 3 days /
--   a week. The longer of the two wins (nobody is offered someone who asked
--   for a pause), and the other side isn't told.
-- - A pause only stops the automatic suggestions: tapping a free friend
--   still asks them. ("Never" stays the 0 rating.)

-- A call that happened: a talk, and 3 quiet days for the pair (each side).
create or replace function public.mark_app_call()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'accepted'
     and (tg_op = 'INSERT' or old.status is distinct from 'accepted') then
    update availability
    set call_until = now() + case when new.quick and new.not_before is null
                                  then interval '2 minutes' else interval '20 minutes' end
    where user_id in (new.user_a, new.user_b);
    update match_offers set talked = coalesce(talked, true) where id = new.id;
    insert into pair_snoozes (from_user, to_user, until)
    values (new.user_a, new.user_b, now() + interval '3 days'),
           (new.user_b, new.user_a, now() + interval '3 days')
    on conflict (from_user, to_user)
    do update set until = greatest(pair_snoozes.until, excluded.until);
  end if;
  if tg_op = 'UPDATE' then
    if new.status = 'accepted' and new.quick
       and new.not_before is not null and old.not_before is null then
      update availability set call_until = now() + interval '20 minutes'
      where user_id in (new.user_a, new.user_b);
    end if;
    if old.status = 'accepted' and new.status <> 'accepted' then
      update availability set call_until = null where user_id in (new.user_a, new.user_b);
      -- Cancelled before it began (quick connect's 5 seconds): no pause.
      delete from pair_snoozes
      where ((from_user = new.user_a and to_user = new.user_b)
             or (from_user = new.user_b and to_user = new.user_a))
        and until <= coalesce(new.accepted_at, now()) + interval '3 days 1 minute';
    end if;
    if new.ended_a and not old.ended_a then
      update availability set call_until = null where user_id = new.user_a;
    end if;
    if new.ended_b and not old.ended_b then
      update availability set call_until = null where user_id = new.user_b;
    end if;
  end if;
  return new;
end;
$$;

-- After the call: when to suggest them again (0 = any time), and whether
-- we really talked.
create or replace function public.after_call(p_offer uuid, p_days integer, p_talked boolean default true)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  o match_offers;
  other uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_days is null or p_days < 0 or p_days > 30 then raise exception 'invalid_days'; end if;
  select * into o from match_offers where id = p_offer for update;
  if not found or me not in (o.user_a, o.user_b) or o.status <> 'accepted' then
    raise exception 'not_found';
  end if;
  other := case when me = o.user_a then o.user_b else o.user_a end;
  update match_offers
  set talked = coalesce(p_talked, true),
      ended_a = ended_a or me = user_a, ended_b = ended_b or me = user_b,
      updated_at = now()
  where id = o.id;
  if p_days = 0 then
    delete from pair_snoozes where from_user = me and to_user = other;
  else
    insert into pair_snoozes (from_user, to_user, until)
    values (me, other, now() + make_interval(days => p_days))
    on conflict (from_user, to_user) do update set until = excluded.until;
  end if;
end;
$$;
revoke all on function public.after_call(uuid, integer, boolean) from public, anon;
grant execute on function public.after_call(uuid, integer, boolean) to authenticated;

-- (Older app) "we didn't talk" now really takes the talk back.
create or replace function public.call_feedback(p_offer uuid, p_result text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform after_call(
    p_offer,
    case p_result when 'not_soon' then 7 else 3 end,
    p_result <> 'no_talk');
end;
$$;
revoke all on function public.call_feedback(uuid, text) from public, anon;
grant execute on function public.call_feedback(uuid, text) to authenticated;

-- A pause only stops automatic suggestions: tapping still asks (D-108).
create or replace function public.ask_check(p_me uuid, p_user uuid, p_me_free boolean)
returns text language plpgsql stable security definer set search_path = public as $$
declare
  theirs availability;
  lo uuid := least(p_me, p_user);
  hi uuid := greatest(p_me, p_user);
begin
  if p_me_free and not exists (
    select 1 from availability where user_id = p_me and expires_at > now()) then
    return 'me_not_free';
  end if;
  select * into theirs from availability where user_id = p_user;
  if not found or p_user = p_me
     or not sees_free_apart_from_name(p_me, theirs)
     or is_anonymous(p_user) or is_anonymous(p_me)
     or pair_pending(p_me, p_user)
     or rating_of(p_user, p_me) = 0 then
    return 'not_free';
  end if;
  if not exists (select 1 from phone_numbers n where n.user_id in (p_me, p_user)) then
    return 'no_number';
  end if;
  if not can_be_asked(p_user) or asked_enough(p_user, theirs.started_at) then
    return 'busy';
  end if;
  if exists (
    select 1 from match_offers o
    where o.user_a = lo and o.user_b = hi
      and ((o.status = 'accepted' and o.accepted_at > now() - interval '30 minutes'
            and not (o.ended_a and o.ended_b))
           -- they already said no to us this time
           or (o.status = 'declined'
               and (case when p_user = o.user_a then o.a_response else o.b_response end)
                   = 'decline'
               and o.created_at >= theirs.started_at))) then
    return 'not_now';
  end if;
  return 'ok';
end;
$$;
revoke all on function public.ask_check(uuid, uuid, boolean) from public, anon, authenticated;

-- Last: the version says 33 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 33 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261033000000_after_call_pause') on conflict do nothing;
