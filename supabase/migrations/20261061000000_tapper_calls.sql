-- DriveBond — whoever taps a friend calls them (D-145, owner).
--
-- When I tap a free friend and they say yes, I'm the one who calls (the
-- phone dials them). Before, the last one to say yes called. Questions the
-- app makes by itself (nobody tapped): as before. The caller still needs the
-- other's number: if only the caller's is shared, the other one calls.

create or replace function public.answer_offer(p_offer uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  pref uuid;
  callee uuid;
  me uuid := auth.uid();
  o match_offers;
  answer text := case when p_accept then 'accept' else 'decline' end;
  withdrawn boolean;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  perform pg_advisory_xact_lock(727274);
  select * into o from match_offers where id = p_offer for update;
  if not found or me not in (o.user_a, o.user_b) then
    return jsonb_build_object('status', 'not_found');
  end if;
  if o.status <> 'pending' then
    return jsonb_build_object(
      'status', o.status,
      'i_call', o.caller = me,
      'phone', case when o.status = 'accepted' and o.caller = me and now() >= o.not_before
                     and o.accepted_at > now() - interval '30 minutes'
                     and are_connected(o.user_a, o.user_b)
                    then call_phone_for(o, me) end);
  end if;
  if o.expires_at <= now()
     or not are_connected(o.user_a, o.user_b)
     or not exists (select 1 from availability where user_id = o.user_a and expires_at > now())
     or not exists (select 1 from availability where user_id = o.user_b and expires_at > now()) then
    update match_offers set status = 'expired', updated_at = now() where id = o.id;
    return jsonb_build_object('status', 'expired');
  end if;

  withdrawn := answer = 'decline'
    and coalesce((case when me = o.user_a then o.a_response else o.b_response end) = 'accept',
                 false);
  if not withdrawn then
    if me = o.user_a then o.a_response := answer; else o.b_response := answer; end if;
  end if;

  if answer = 'decline' then
    o.status := 'declined';
  elsif o.a_response = 'accept' and o.b_response = 'accept' then
    if in_call(o.user_a, o.id) or in_call(o.user_b, o.id) then
      -- Both said yes, but one is in another call: keep the answers, so
      -- nobody is marked "didn't answer".
      update match_offers
        set status = 'expired', a_response = o.a_response, b_response = o.b_response,
            updated_at = now()
      where id = o.id;
      return jsonb_build_object('status', 'expired');
    end if;
    o.status := 'accepted';
    -- Who calls: whoever tapped the other (owner, D-145); otherwise the
    -- last to say yes. The caller needs the other's number — if only the
    -- caller's is shared, the other one calls instead.
    pref := coalesce(o.asked_by, me);
    callee := case when pref = o.user_a then o.user_b else o.user_a end;
    o.caller := case
      when not exists (select 1 from phone_numbers where user_id = callee)
           and exists (select 1 from phone_numbers where user_id = pref)
      then callee
      else pref end;
    o.accepted_at := now();
    o.not_before := now();
  end if;

  update match_offers
    set a_response = o.a_response, b_response = o.b_response, status = o.status,
        caller = o.caller, accepted_at = o.accepted_at, not_before = o.not_before,
        updated_at = now()
  where id = o.id;

  if o.status = 'accepted' then
    update match_offers set status = 'cancelled', updated_at = now()
    where status = 'pending' and id <> o.id
      and (o.user_a in (user_a, user_b) or o.user_b in (user_a, user_b));
  end if;

  return jsonb_build_object(
    'status', o.status,
    'i_call', o.status = 'accepted' and o.caller = me,
    'phone', case when o.status = 'accepted' and o.caller = me then call_phone_for(o, me) end);
end;
$$;
revoke all on function public.answer_offer(uuid, boolean) from public, anon;
grant execute on function public.answer_offer(uuid, boolean) to authenticated;

-- Last: the version says 61 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 61 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261061000000_tapper_calls') on conflict do nothing;

notify pgrst, 'reload schema';
