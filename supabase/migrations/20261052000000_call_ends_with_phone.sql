-- DriveBond — "in a call" ends when the phone call ends (D-131).
--
-- A call agreed through the app counted as "in a call" until the person
-- answered "how was it?" in the app (up to 20 minutes). Someone who hangs
-- up and keeps driving looked busy all that time. Now, when the phone says
-- its call is over, that person's side of an agreed app call is over too.
-- (Their "how was it?" still shows when they open the app.)

create or replace function public.device_phone_call(p_token text, p_on boolean)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
  was_on boolean;
begin
  if me is null then return 'bad_token'; end if;
  select phone_until is not null into was_on from availability where user_id = me;
  update availability
  set phone_until = case when p_on then now() + interval '3 minutes' else null end
  where user_id = me;
  if p_on then
    update match_offers set status = 'cancelled', updated_at = now()
    where status = 'pending' and me in (user_a, user_b);
  elsif coalesce(was_on, false) then
    -- The phone call is over: so is my side of an agreed app call.
    update match_offers
    set ended_a = ended_a or me = user_a,
        ended_b = ended_b or me = user_b,
        updated_at = now()
    where status = 'accepted' and me in (user_a, user_b)
      and accepted_at is not null and accepted_at > now() - interval '2 hours'
      and not (case when me = user_a then ended_a else ended_b end)
      and (not quick or (not_before is not null and not_before < now()));
  end if;
  return 'ok';
end;
$$;
revoke all on function public.device_phone_call(text, boolean) from public;
grant execute on function public.device_phone_call(text, boolean) to anon, authenticated;

-- Last: the version says 52 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 52 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261052000000_call_ends_with_phone') on conflict do nothing;
