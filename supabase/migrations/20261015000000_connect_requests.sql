-- DriveTalk — finding friends without giving my number (D-070).
--
-- Two ways now, side by side:
--   1. Both saved each other's number → connected at once (as before; needs
--      both numbers).
--   2. I saved their number and they use DriveTalk → they get a request
--      "X wants to connect" and decide. My number is not needed for this.
-- Nobody is connected to anyone without either both numbers or a "yes".

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 15 $$;
grant execute on function public.schema_version() to anon, authenticated;

create table if not exists public.connect_requests (
  from_user uuid not null references public.profiles (id) on delete cascade,
  to_user uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (from_user, to_user),
  check (from_user <> to_user)
);
create index if not exists connect_requests_to_idx on public.connect_requests (to_user, status);
alter table public.connect_requests enable row level security;
revoke all on public.connect_requests from anon, authenticated;
grant select on public.connect_requests to authenticated;
drop policy if exists "connect requests: mine" on public.connect_requests;
create policy "connect requests: mine" on public.connect_requests
  for select to authenticated using (auth.uid() in (from_user, to_user));

-- Replace my contact hashes; connect or ask. Returns first names with
-- kind 'connected' (now friends) or 'requested' (asked, waiting for them).
create or replace function public.find_friends(p_hashes text[])
returns table (display_name text, kind text)
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

  for other in
    select pn.user_id, pr.display_name,
           (my_hash is not null and exists (
              select 1 from contact_hashes c
              where c.owner = pn.user_id and c.hash = my_hash)) as has_me,
           exists (select 1 from connect_requests r
                   where r.from_user = pn.user_id and r.to_user = me
                     and r.status = 'pending') as asked_me,
           exists (select 1 from connect_requests r
                   where r.from_user = me and r.to_user = pn.user_id) as i_asked
    from phone_numbers pn
    join profiles pr on pr.id = pn.user_id
    where pn.user_id <> me
      and pn.phone_hash in (select hash from contact_hashes where owner = me)
      and not is_blocked_between(me, pn.user_id)
      and not are_connected(me, pn.user_id)
  loop
    if other.has_me or other.asked_me then
      -- Both saved each other, or they asked for me and I have them.
      insert into connections (user_a, user_b)
      values (least(me, other.user_id), greatest(me, other.user_id))
      on conflict do nothing;
      update connect_requests set status = 'accepted', updated_at = now()
      where status = 'pending'
        and ((from_user = me and to_user = other.user_id)
             or (from_user = other.user_id and to_user = me));
      display_name := other.display_name;
      kind := 'connected';
      return next;
    elsif not other.i_asked then
      -- Asked once per pair (a "no" is never asked again).
      insert into connect_requests (from_user, to_user)
      values (me, other.user_id)
      on conflict do nothing;
      display_name := other.display_name;
      kind := 'requested';
      return next;
    end if;
  end loop;
  perform create_offers_for(me);
end;
$$;
revoke all on function public.find_friends(text[]) from public, anon;
grant execute on function public.find_friends(text[]) to authenticated;

-- Older app versions: same rules, only the new connections are returned.
create or replace function public.sync_contacts(p_hashes text[])
returns table (display_name text)
language sql security definer set search_path = public as $$
  select f.display_name from public.find_friends(p_hashes) f where f.kind = 'connected';
$$;
revoke all on function public.sync_contacts(text[]) from public, anon;
grant execute on function public.sync_contacts(text[]) to authenticated;

-- Requests waiting for my answer (first name only).
create or replace function public.incoming_requests()
returns table (from_user uuid, display_name text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.from_user, p.display_name, r.created_at
  from connect_requests r
  join profiles p on p.id = r.from_user
  where r.to_user = auth.uid() and r.status = 'pending'
    and not is_blocked_between(r.from_user, r.to_user)
    and not are_connected(r.from_user, r.to_user)
  order by r.created_at;
$$;
revoke all on function public.incoming_requests() from public, anon;
grant execute on function public.incoming_requests() to authenticated;

-- Yes → connected. No → quietly closed (they are not told, not asked again).
create or replace function public.answer_request(p_from uuid, p_accept boolean)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  update connect_requests
  set status = case when p_accept then 'accepted' else 'declined' end,
      updated_at = now()
  where from_user = p_from and to_user = me and status = 'pending';
  if not found then return false; end if;
  if p_accept and not is_blocked_between(me, p_from) then
    insert into connections (user_a, user_b)
    values (least(me, p_from), greatest(me, p_from))
    on conflict do nothing;
    perform create_offers_for(me);
  end if;
  return true;
end;
$$;
revoke all on function public.answer_request(uuid, boolean) from public, anon;
grant execute on function public.answer_request(uuid, boolean) to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.connect_requests;
exception when others then
  raise notice 'realtime: %', sqlerrm;
end;
$$;

insert into public.drivetalk_migrations (name)
values ('20261015000000_connect_requests') on conflict do nothing;
