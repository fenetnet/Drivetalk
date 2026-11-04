-- DriveBond — quick connect is per person only (D-116).
--
-- Groups say only who sees that I'm free. Quick connect is the switch on
-- each friend's card. Whoever was in a quick group of mine keeps quick
-- connect: they get the per-person switch instead.

insert into public.quick_picks (owner, member)
select c.owner, m.member
from public.circles c
join public.circle_members m on m.circle_id = c.id
where c.quick
  and public.are_connected(c.owner, m.member)
  and not public.is_blocked_between(c.owner, m.member)
on conflict do nothing;

update public.circles set quick = false where quick;

-- Quick with someone: only the per-person switch.
create or replace function public.is_quick(x uuid, y uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from quick_picks q where q.owner = x and q.member = y);
$$;
revoke all on function public.is_quick(uuid, uuid) from public, anon, authenticated;

-- An older app may still mark a group "quick": its members get the
-- per-person switch, and the group stays a plain group.
create or replace function public.circle_quick_to_people()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.quick then
    insert into quick_picks (owner, member)
    select new.owner, m.member from circle_members m
    where m.circle_id = new.id
      and are_connected(new.owner, m.member)
      and not is_blocked_between(new.owner, m.member)
    on conflict do nothing;
    new.quick := false;
  end if;
  return new;
end;
$$;
revoke all on function public.circle_quick_to_people() from public, anon, authenticated;
drop trigger if exists circle_quick_to_people on public.circles;
create trigger circle_quick_to_people before insert or update of quick on public.circles
  for each row execute function public.circle_quick_to_people();

-- Last: the version says 41 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 41 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261041000000_quick_per_person_only') on conflict do nothing;
