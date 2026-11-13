-- DriveBond — only friends I can really ask (D-107).
--
-- Free friends are shown (also while driving) only when tapping them
-- would really ask them: not someone who rated me "never", hides from me,
-- is busy, didn't answer, is in a trip's first quiet minutes, already said
-- no to me this time, or talked with me in the last 30 minutes.
-- One check, used both for the list and for the tap itself.

-- Why I can't ask p_user right now ('ok' = I can). With p_me_free, my
-- own free time is checked too (for the tap); without it, only theirs
-- (for the list).
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
     or rating_of(p_user, p_me) = 0
     or exists (select 1 from pair_snoozes z
                where z.until > now() and z.from_user = p_user and z.to_user = p_me) then
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
      and ((o.status = 'accepted' and o.accepted_at > now() - interval '30 minutes')
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

-- Free friends I can ask right now (ids only; the app already sees them).
create or replace function public.askable_friends()
returns setof uuid language sql stable security definer set search_path = public as $$
  select a.user_id from availability a
  where a.user_id <> auth.uid()
    and a.expires_at > now()
    and ask_check(auth.uid(), a.user_id, false) = 'ok';
$$;
revoke all on function public.askable_friends() from public, anon;
grant execute on function public.askable_friends() to authenticated;

create or replace function public.ask_friend(p_user uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  mine availability;
  theirs availability;
  lo uuid;
  hi uuid;
  why text;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  perform pg_advisory_xact_lock(727274);
  if (select count(*) from match_offers o
      where o.direct and me in (o.user_a, o.user_b)
        and o.created_at > now() - interval '1 hour') >= 10 then
    return 'rate_limited';
  end if;
  why := ask_check(me, p_user, true);
  if why <> 'ok' then return why; end if;
  select * into mine from availability where user_id = me;
  select * into theirs from availability where user_id = p_user;
  lo := least(me, p_user);
  hi := greatest(me, p_user);
  -- My own open question (if any) gives way to this one.
  update match_offers set status = 'cancelled', updated_at = now()
  where status = 'pending' and me in (user_a, user_b);
  insert into match_offers (user_a, user_b, expires_at, shared_until, last_talk, direct,
                            a_response, b_response)
  values (lo, hi, least(mine.expires_at, theirs.expires_at, now() + interval '2 minutes'),
          case
            when mine.source = 'manual' and theirs.source = 'manual'
              then least(mine.expires_at, theirs.expires_at)
            when mine.source = 'manual' then mine.expires_at
            when theirs.source = 'manual' then theirs.expires_at
          end,
          (select max(o.accepted_at) from match_offers o
           where o.status = 'accepted' and o.talked and o.user_a = lo and o.user_b = hi),
          true,
          case when me = lo then 'accept' end,
          case when me = hi then 'accept' end);
  return 'asked';
end;
$$;
revoke all on function public.ask_friend(uuid) from public, anon;
grant execute on function public.ask_friend(uuid) to authenticated;

-- Last: the version says 32 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 32 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261032000000_who_i_can_ask') on conflict do nothing;
