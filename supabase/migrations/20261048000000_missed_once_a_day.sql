-- DriveBond — "X tried to reach you" at most once a day per person (D-121,
-- owner: no overload). The day is the person's own (their time zone); the
-- first such note of the day is the one sent.

create or replace function public.missed_push()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  side record;
begin
  if new.status in ('declined', 'expired', 'cancelled')
     and old.status = 'pending' and not new.quick then
    for side in
      select new.user_a as me, new.user_b as other
      where new.a_response is null and new.b_response = 'accept'
      union all
      select new.user_b, new.user_a
      where new.b_response is null and new.a_response = 'accept'
    loop
      perform push_queue(side.me, 'missed',
        (select jsonb_build_object('from', p.id, 'name', p.display_name, 'gender', p.gender)
         from profiles p where p.id = side.other),
        'missed:' || side.me || ':' || (
          select to_char(now() at time zone coalesce(p.time_zone, 'Asia/Jerusalem'), 'YYYYMMDD')
          from profiles p where p.id = side.me));
    end loop;
  end if;
  return null;
end;
$$;
revoke all on function public.missed_push() from public, anon, authenticated;

-- Last: the version says 48 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 48 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261048000000_missed_once_a_day') on conflict do nothing;
