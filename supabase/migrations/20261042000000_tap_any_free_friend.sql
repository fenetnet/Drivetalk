-- DriveBond — tapping a free friend works whatever my own settings (D-117).
--
-- The owner: a friend I see as free can always be tapped and asked, even
-- when I haven't said I'm free, or my groups / "everyone else" don't show
-- them my free time. Tapping marks me free (the app does it) and the
-- question goes to them directly. Server 40 had added "they must also see
-- that I'm free" — removed again.

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

-- Last: the version says 42 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 42 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261042000000_tap_any_free_friend') on conflict do nothing;
