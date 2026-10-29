-- DriveBond — "X is on the way" goes to friends with ⚡ auto-yes for me
-- (owner, D-161: quick connect leaves the app; auto-yes replaces it).
-- Same limits as before: driving, once per 20 hours per friend, not in
-- their quiet hours, not when they are free themselves.

create or replace function public.trip_push_claim(p_user uuid)
returns table (friend_id uuid, push_token text, from_name text)
language plpgsql security definer set search_path = public as $$
declare
  mine availability;
  my_name text;
begin
  select * into mine from availability a where a.user_id = p_user and a.expires_at > now();
  if not found or mine.mode <> 'driving' or mine.missed_at is not null
     or coalesce(mine.quiet_until > now(), false) then
    return;
  end if;
  if not coalesce((select p.trip_notify from profiles p where p.id = p_user), true)
     or is_anonymous(p_user) or hides_status(p_user) then
    return;
  end if;
  select p.display_name into my_name from profiles p where p.id = p_user;
  return query
  with targets as (
    select f.id as fid from profiles f
    where f.id <> p_user
      -- Friends whose ⚡ auto-yes covers me (D-161); old quick-connect
      -- pairs still count until everyone has the new app.
      and ((f.auto_yes and rating_of(f.id, p_user) >= f.auto_yes_min)
           or (is_quick(p_user, f.id) and is_quick(f.id, p_user)))
      and sees_free_apart_from_name(f.id, mine)
      and not is_anonymous(f.id)
      and not in_quiet_hours(f.id)
      and rating_of(f.id, p_user) <> 0
      and not exists (select 1 from availability a
                      where a.user_id = f.id and a.expires_at > now())
      and not exists (select 1 from pair_snoozes s
                      where s.chosen and s.until > now()
                        and ((s.from_user = f.id and s.to_user = p_user)
                             or (s.from_user = p_user and s.to_user = f.id)))
      and not exists (select 1 from trip_pushes t
                      where t.owner = p_user and t.member = f.id
                        and t.sent_at > now() - interval '20 hours')
      and exists (select 1 from push_tokens pt where pt.user_id = f.id)
  ), marked as (
    insert into trip_pushes (owner, member, sent_at)
    select p_user, targets.fid, now() from targets
    on conflict (owner, member) do update set sent_at = excluded.sent_at
    returning trip_pushes.member as mid
  )
  select marked.mid, pt.token, my_name
  from marked join push_tokens pt on pt.user_id = marked.mid;
end;
$$;
revoke all on function public.trip_push_claim(uuid) from public, anon, authenticated;
grant execute on function public.trip_push_claim(uuid) to service_role;

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 67 $$;

insert into public.drivetalk_migrations (name)
values ('20261067000000_trip_push_auto_yes') on conflict do nothing;

notify pgrst, 'reload schema';
