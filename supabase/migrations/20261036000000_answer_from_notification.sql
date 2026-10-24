-- DriveBond — "yes" straight from the notification (D-111).
--
-- When the app is in the background (driving, another app, locked
-- screen), "Talk" in the notification answers at once — no need to open
-- the app. The phone can't dial from the background, so whoever answered
-- from the notification is the one who gets called (when they shared a
-- number): their phone simply rings, like any call (also in the car).
-- If that's not possible, a notification says "tap to call X".

-- Answer "yes" with the phone's device token (the background service).
create or replace function public.device_answer(p_token text, p_offer uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
  r jsonb;
  o match_offers;
  other uuid;
begin
  if me is null then return jsonb_build_object('status', 'bad_token'); end if;
  -- The very same answer as in the app, as this user.
  perform set_config('request.jwt.claim.sub', me::text, true);
  r := answer_offer(p_offer, true);
  if r ->> 'status' = 'accepted' then
    select * into o from match_offers where id = p_offer;
    other := case when me = o.user_a then o.user_b else o.user_a end;
    -- I can't dial from here: the other side calls me, if they can.
    if o.caller = me and exists (select 1 from phone_numbers where user_id = me) then
      update match_offers set caller = other, updated_at = now() where id = o.id;
      return jsonb_build_object('status', 'accepted', 'i_call', false);
    end if;
    return jsonb_build_object('status', 'accepted', 'i_call', o.caller = me);
  end if;
  return jsonb_build_object('status', r ->> 'status');
end;
$$;
revoke all on function public.device_answer(text, uuid) from public;
grant execute on function public.device_answer(text, uuid) to anon, authenticated;

-- Calls agreed in the last 2 minutes that this phone should know about
-- (I call them → "tap to call"; they call me → "X is calling you now").
create or replace function public.device_calls(p_token text)
returns table(offer_id uuid, other_name text, other_id uuid, i_call boolean)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
begin
  if me is null then return; end if;
  return query
    select o.id, p.display_name, p.id, o.caller = me
    from match_offers o
    join profiles p on p.id = case when o.user_a = me then o.user_b else o.user_a end
    where me in (o.user_a, o.user_b)
      and o.status = 'accepted'
      and o.caller is not null
      and o.accepted_at > now() - interval '2 minutes'
      and not (case when o.user_a = me then o.ended_a else o.ended_b end)
      and are_connected(o.user_a, o.user_b)
      and not is_blocked_between(o.user_a, o.user_b);
end;
$$;
revoke all on function public.device_calls(text) from public;
grant execute on function public.device_calls(text) to anon, authenticated;

-- Last: the version says 36 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 36 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261036000000_answer_from_notification') on conflict do nothing;
