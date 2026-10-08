-- DriveBond — bring back someone I removed (D-090).
--
-- A removal now remembers who removed. "People I removed" lists only the
-- ones I removed (not people who removed me), and I can bring them back:
-- connected at once, like picking from contacts. Never a blocked pair.
-- Removals from before this file don't know who removed: they count as
-- mine for both sides (prototype; few people).

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 24 $$;
grant execute on function public.schema_version() to anon, authenticated;

alter table public.removed_pairs add column if not exists removed_by uuid;

create or replace function public.remember_removed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    if exists (select 1 from profiles where id = old.user_a)
       and exists (select 1 from profiles where id = old.user_b) then
      insert into removed_pairs (user_a, user_b, removed_by)
      values (old.user_a, old.user_b, auth.uid())
      on conflict (user_a, user_b) do update set removed_by = excluded.removed_by,
                                                 created_at = now();
    end if;
    return old;
  end if;
  delete from removed_pairs where user_a = new.user_a and user_b = new.user_b;
  return new;
end;
$$;

-- People I removed (newest first).
create or replace function public.my_removed()
returns table (user_id uuid, display_name text)
language sql stable security definer set search_path = public as $$
  select p.id, p.display_name
  from removed_pairs r
  join profiles p on p.id = case when r.user_a = auth.uid() then r.user_b else r.user_a end
  where auth.uid() in (r.user_a, r.user_b)
    and (r.removed_by = auth.uid() or r.removed_by is null)
    and not is_blocked_between(r.user_a, r.user_b)
  order by r.created_at desc;
$$;
revoke all on function public.my_removed() from public, anon;
grant execute on function public.my_removed() to authenticated;

-- Bring one back: friends again at once.
create or replace function public.restore_friend(p_user uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from removed_pairs r
    where r.user_a = least(me, p_user) and r.user_b = greatest(me, p_user)
      and (r.removed_by = me or r.removed_by is null)
  ) or is_blocked_between(me, p_user) then
    return false;
  end if;
  insert into connections (user_a, user_b)
  values (least(me, p_user), greatest(me, p_user))
  on conflict do nothing;
  perform create_offers_for(me);
  return true;
end;
$$;
revoke all on function public.restore_friend(uuid) from public, anon;
grant execute on function public.restore_friend(uuid) to authenticated;

insert into public.drivetalk_migrations (name)
values ('20261024000000_bring_back') on conflict do nothing;
