-- DriveBond — quick connect per person (D-112).
--
-- Quick connect no longer needs a group: on a friend's card, "Quick
-- connect" is one switch. When BOTH turned it on for each other and both
-- are free, the call starts by itself after 5 seconds anyone can cancel
-- (D-026 limits unchanged). The friend sees, once in the app, "X wants
-- quick connect with you — turn it on too?". Quick-connect groups keep
-- working as before.

create table if not exists public.quick_picks (
  owner uuid not null references public.profiles(id) on delete cascade,
  member uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner, member)
);
alter table public.quick_picks enable row level security;
revoke all on public.quick_picks from public, anon, authenticated;

-- Quick with someone: a quick group, or the per-person switch.
create or replace function public.is_quick(x uuid, y uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from circles c join circle_members m on m.circle_id = c.id
    where c.owner = x and c.quick and m.member = y
  ) or exists (
    select 1 from quick_picks q where q.owner = x and q.member = y
  );
$$;
revoke all on function public.is_quick(uuid, uuid) from public, anon, authenticated;

-- The switch on a friend's card.
create or replace function public.set_quick(p_user uuid, p_on boolean)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_on then
    if p_user = me or not are_connected(me, p_user) or is_blocked_between(me, p_user) then
      raise exception 'not_found';
    end if;
    insert into quick_picks (owner, member) values (me, p_user) on conflict do nothing;
  else
    delete from quick_picks where owner = me and member = p_user;
  end if;
  return p_on;
end;
$$;
revoke all on function public.set_quick(uuid, boolean) from public, anon;
grant execute on function public.set_quick(uuid, boolean) to authenticated;

-- For my friends: did I turn it on (also via a quick group), and did they
-- turn it on for me? Only friends, never anyone else.
create or replace function public.quick_status()
returns table(user_id uuid, mine boolean, theirs boolean)
language sql stable security definer set search_path = public as $$
  select f.id, is_quick(auth.uid(), f.id), is_quick(f.id, auth.uid())
  from profiles f
  where f.id <> auth.uid()
    and are_connected(auth.uid(), f.id)
    and not is_blocked_between(auth.uid(), f.id)
    and (is_quick(auth.uid(), f.id) or is_quick(f.id, auth.uid()));
$$;
revoke all on function public.quick_status() from public, anon;
grant execute on function public.quick_status() to authenticated;

-- No longer friends (removed or blocked): the switch goes too.
create or replace function public.quick_picks_unfriend()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from quick_picks
  where (owner = old.user_a and member = old.user_b)
     or (owner = old.user_b and member = old.user_a);
  return old;
end;
$$;
revoke all on function public.quick_picks_unfriend() from public, anon, authenticated;
drop trigger if exists quick_picks_unfriend on public.connections;
create trigger quick_picks_unfriend after delete on public.connections
  for each row execute function public.quick_picks_unfriend();

-- Last: the version says 37 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 37 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261037000000_quick_per_person') on conflict do nothing;
