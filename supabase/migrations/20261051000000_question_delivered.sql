-- DriveBond — "it reached their phone" (D-129, owner: an update at every
-- step so the one waiting doesn't lose patience).
--
-- When a question shows on someone's phone (in the app, or as a
-- notification from the background service or a push), the phone says so.
-- The one who asked then sees "sent" → "it reached X's phone" → the answer.
-- Only a time is kept, on the question itself; it goes with the question.
-- Older apps don't read it and don't need to.

alter table public.match_offers
  add column if not exists shown_a timestamptz,
  add column if not exists shown_b timestamptz;

create or replace function public.offer_shown_for(p_offer uuid, p_user uuid)
returns void language sql security definer set search_path = public as $$
  update match_offers
  set shown_a = case when p_user = user_a then coalesce(shown_a, now()) else shown_a end,
      shown_b = case when p_user = user_b then coalesce(shown_b, now()) else shown_b end,
      updated_at = now()
  where id = p_offer and status = 'pending' and p_user in (user_a, user_b)
    and (case when p_user = user_a then shown_a else shown_b end) is null;
$$;
revoke all on function public.offer_shown_for(uuid, uuid) from public, anon, authenticated;

-- From the app.
create or replace function public.offer_shown(p_offer uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  perform offer_shown_for(p_offer, auth.uid());
end;
$$;
revoke all on function public.offer_shown(uuid) from public, anon;
grant execute on function public.offer_shown(uuid) to authenticated;

-- From the background service / a push (device token, like the others).
create or replace function public.device_offer_shown(p_token text, p_offer uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
begin
  if me is null then return 'bad_token'; end if;
  perform offer_shown_for(p_offer, me);
  return 'ok';
end;
$$;
revoke all on function public.device_offer_shown(text, uuid) from public;
grant execute on function public.device_offer_shown(text, uuid) to anon, authenticated;

-- Last: the version says 51 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 51 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261051000000_question_delivered') on conflict do nothing;
