-- DriveBond — one person, one row in my list (D-099).
--
-- Reinstalling the app makes a new account; the old one stays connected to
-- friends, so they saw the same person two or three times. Now an account
-- is hidden from friends when another account with the SAME phone number
-- was opened more recently AND this one hasn't been opened for a day.
-- Nothing is deleted: if the old account is opened again, it shows again.
-- (Numbers aren't verified, so nothing is merged or moved between accounts.)

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 28 $$;
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
      and me.last_seen_at < now() - interval '1 day'
      and newer.last_seen_at > me.last_seen_at);
$$;
revoke all on function public.replaced_account(uuid) from public, anon;
grant execute on function public.replaced_account(uuid) to authenticated;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (
    id = auth.uid()
    or (public.are_connected(auth.uid(), id)
        and not public.is_blocked_between(auth.uid(), id)
        and not public.replaced_account(id))
  );

insert into public.drivetalk_migrations (name)
values ('20261028000000_one_account_per_number') on conflict do nothing;
