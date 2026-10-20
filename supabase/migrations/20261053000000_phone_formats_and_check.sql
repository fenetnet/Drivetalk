-- DriveBond — two number formats that didn't match, and "why isn't X
-- here?" (D-132, owner: a contact showed for him and not for his wife).
--
-- 1. Numbers saved as "+972-050-…" (an extra 0 after the country code) and
--    Israeli numbers saved without the leading 0 ("50-680-2360") now mean
--    the same number as "050-680-2360". Same rule as the app
--    (lib/real/real_models.dart: e164Phone); stored numbers are re-hashed.
-- 2. contact_check(hash): for the test screen — is this number on
--    DriveBond, and if so why it may not show (removed / blocked / friend).
--    Counts toward the same daily limit as the contacts search.

create or replace function public.e164(p text)
returns text language plpgsql immutable as $$
declare
  plus boolean := btrim(coalesce(p, '')) like '+%';
  d text := regexp_replace(coalesce(p, ''), '[^0-9]', '', 'g');
begin
  if d = '' then return null; end if;
  if plus then
    d := d;
  elsif d like '00%' then
    d := substr(d, 3);
  elsif d like '972%' then
    d := d;
  elsif d like '0%' then
    d := '972' || substr(d, 2);
  elsif length(d) = 9 and (d like '5%' or d like '7%') then
    -- An Israeli mobile saved without its 0.
    d := '972' || d;
  end if;
  -- "+972 0…": the 0 doesn't belong after the country code.
  if d like '9720%' then
    d := '972' || substr(d, 5);
  end if;
  if length(d) < 8 or length(d) > 15 then return null; end if;
  return '+' || d;
end;
$$;

-- Stored numbers: the same rule now (the trigger recomputes the hash).
update public.phone_numbers
set phone = phone
where phone_hash is distinct from encode(extensions.digest(public.e164(phone), 'sha256'), 'hex');

create or replace function public.contact_check(p_hash text)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  other uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_hash is null or p_hash !~ '^[0-9a-f]{64}$' then return 'bad'; end if;
  if (select count(*) from contact_searches cs
      where cs.user_id = me and cs.at > now() - interval '1 day') >= 30 then
    return 'rate_limited';
  end if;
  insert into contact_searches (user_id) values (me);
  if exists (select 1 from phone_numbers where user_id = me and phone_hash = p_hash) then
    return 'me';
  end if;
  select pn.user_id into other
  from phone_numbers pn join profiles pr on pr.id = pn.user_id
  where pn.phone_hash = p_hash
  order by replaced_account(pn.user_id) asc, pr.last_seen_at desc
  limit 1;
  if other is null then return 'not_user'; end if;
  if is_blocked_between(me, other) then return 'blocked'; end if;
  if are_connected(me, other) then return 'friend'; end if;
  if was_removed(me, other) then return 'removed'; end if;
  return 'user';
end;
$$;
revoke all on function public.contact_check(text) from public, anon;
grant execute on function public.contact_check(text) to authenticated;

-- Last: the version says 53 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 53 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261053000000_phone_formats_and_check') on conflict do nothing;
