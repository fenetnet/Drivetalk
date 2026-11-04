-- DriveBond — "Shlomi wants to talk with you" (D-109).
--
-- When a friend tapped me (not the app's suggestion), the phone's
-- background check says so, so the notification and the voice can say
-- "X wants to talk with you" instead of "X is free".

create or replace function public.auto_offers(p_token text)
returns table (offer_id uuid, other_name text, kind text, not_before timestamptz, other_id uuid)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
  q record;
begin
  if me is null then return; end if;
  perform create_offers_for(me);
  for q in
    select o.id from match_offers o
    where me in (o.user_a, o.user_b) and o.quick and o.status = 'accepted'
      and o.not_before is null and o.accepted_at > now() - interval '3 minutes'
  loop
    perform mark_seen(q.id, me);
  end loop;
  return query
    select o.id, p.display_name,
           case when o.quick then 'quick'
                when o.direct then 'direct'
                else 'ask' end,
           o.not_before,
           p.id
    from match_offers o
    join profiles p on p.id = case when o.user_a = me then o.user_b else o.user_a end
    where me in (o.user_a, o.user_b)
      and not is_blocked_between(o.user_a, o.user_b)
      and (
        (o.status = 'pending' and o.expires_at > now()
         and (case when o.user_a = me then o.a_response else o.b_response end) is null)
        or (o.quick and o.status = 'accepted' and o.accepted_at > now() - interval '3 minutes'
            and o.caller is null)
      )
    order by o.created_at;
end;
$$;
grant execute on function public.auto_offers(text) to anon, authenticated;

-- Last: the version says 34 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 34 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261034000000_direct_ask_named') on conflict do nothing;
