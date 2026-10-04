-- DriveTalk — friends from phone contacts (owner decision D-047).
--
-- People who have EACH OTHER's number in their phone contacts become
-- connected automatically (both directions are required — just having
-- someone's number is not enough).
--
-- Privacy: phones never send contact numbers in the clear — only SHA-256
-- hashes of the normalized number (+972…). Names from the contacts never
-- leave the phone. Note: hashes of phone numbers can be guessed by brute
-- force, so they are readable by nobody (no RLS read policy, functions only).

-- Same normalization as the app (lib/real/real_models.dart: e164Phone).
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
  end if;
  if length(d) < 8 or length(d) > 15 then return null; end if;
  return '+' || d;
end;
$$;

alter table public.phone_numbers add column if not exists phone_hash text;

create or replace function public.phone_numbers_hash()
returns trigger language plpgsql set search_path = public, extensions as $$
begin
  new.phone_hash := encode(extensions.digest(public.e164(new.phone), 'sha256'), 'hex');
  return new;
end;
$$;
drop trigger if exists phone_numbers_hash on public.phone_numbers;
create trigger phone_numbers_hash before insert or update of phone on public.phone_numbers
  for each row execute function public.phone_numbers_hash();
update public.phone_numbers set phone = phone; -- fill hashes for existing rows
create index if not exists phone_numbers_hash_idx on public.phone_numbers (phone_hash);

create table if not exists public.contact_hashes (
  owner uuid not null references public.profiles (id) on delete cascade,
  hash text not null check (hash ~ '^[0-9a-f]{64}$'),
  primary key (owner, hash)
);
create index if not exists contact_hashes_hash_idx on public.contact_hashes (hash);
alter table public.contact_hashes enable row level security;
-- No policies: only sync_contacts() reads or writes it.

-- Replace my contact hashes and connect with everyone who has me too.
-- Returns the first names of new connections.
create or replace function public.sync_contacts(p_hashes text[])
returns table (display_name text)
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
  insert into contact_hashes (owner, hash)
  select distinct me, h from unnest(p_hashes) as h
  where h ~ '^[0-9a-f]{64}$'
  on conflict do nothing;

  select phone_hash into my_hash from phone_numbers where user_id = me;
  if my_hash is null then return; end if;

  for other in
    select pn.user_id, pr.display_name
    from phone_numbers pn
    join profiles pr on pr.id = pn.user_id
    where pn.user_id <> me
      and pn.phone_hash in (select hash from contact_hashes where owner = me)
      and exists (select 1 from contact_hashes c
                  where c.owner = pn.user_id and c.hash = my_hash)
      and not is_blocked_between(me, pn.user_id)
      and not are_connected(me, pn.user_id)
  loop
    insert into connections (user_a, user_b)
    values (least(me, other.user_id), greatest(me, other.user_id))
    on conflict do nothing;
    display_name := other.display_name;
    return next;
  end loop;
  perform create_offers_for(me);
end;
$$;

revoke all on function public.sync_contacts(text[]) from public, anon;
grant execute on function public.sync_contacts(text[]) to authenticated;
