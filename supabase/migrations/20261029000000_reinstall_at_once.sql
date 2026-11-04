-- DriveBond — a reinstall shows once right away (D-101).
--
-- D-099 hid an older account with the same number only after a day unused.
-- But a reinstall has a clear sign: the new account was CREATED after the
-- old one was last opened. Then the old one is hidden at once. If the old
-- account is opened again later, it shows again (nothing is deleted).

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 29 $$;
grant execute on function public.schema_version() to anon, authenticated;

create or replace function public.replaced_account(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from phone_numbers mine
    join profiles me on me.id = mine.user_id
    join phone_numbers other
      on other.phone_hash = mine.phone_hash and other.user_id <> mine.user_id
    join profiles newer on newer.id = other.user_id
    where mine.user_id = p_user
      and mine.phone_hash is not null
      and (
        -- reinstalled: the new account was made after the old one's last use
        newer.created_at > me.last_seen_at
        -- or: the other one is in use and this one wasn't opened for a day
        or (me.last_seen_at < now() - interval '1 day'
            and newer.last_seen_at > me.last_seen_at)));
$$;
revoke all on function public.replaced_account(uuid) from public, anon;
grant execute on function public.replaced_account(uuid) to authenticated;

insert into public.drivetalk_migrations (name)
values ('20261029000000_reinstall_at_once') on conflict do nothing;
