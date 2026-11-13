-- DriveBond — the owner's code lives only in the database (D-093).
--
-- The owner's code was public (it was in the app and in this public
-- repository), so anyone could become "owner" and read feedback and
-- reports. Now only a SHA-256 of the code is kept, in a table nobody can
-- read, and it is set by the owner directly in the database (never in git).
-- Everyone who was "owner" is removed: the owner enters the new code once.

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 25 $$;
grant execute on function public.schema_version() to anon, authenticated;

-- ------------------------------------------------------------ owner code

create table if not exists public.owner_secret (
  id integer primary key default 1 check (id = 1),
  code_hash text not null
);
alter table public.owner_secret enable row level security;
revoke all on public.owner_secret from anon, authenticated;

delete from public.app_owners;

-- At most 5 tries an hour per account; no secret set yet = nobody.
create or replace function public.claim_owner(p_code text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if (select count(*) from owner_claims where user_id = me and at > now() - interval '1 hour') >= 5 then
    return false;
  end if;
  insert into owner_claims (user_id) values (me);
  if not exists (
    select 1 from owner_secret
    where id = 1
      and code_hash = encode(extensions.digest('drivetalk-admin:' || btrim(coalesce(p_code, '')), 'sha256'), 'hex')
  ) then
    return false;
  end if;
  insert into app_owners (user_id) values (me) on conflict do nothing;
  return true;
end;
$$;
revoke all on function public.claim_owner(text) from public, anon;
grant execute on function public.claim_owner(text) to authenticated;

insert into public.drivetalk_migrations (name)
values ('20261025000000_owner_code') on conflict do nothing;
