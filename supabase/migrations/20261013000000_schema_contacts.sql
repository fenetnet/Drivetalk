-- DriveTalk — server version, and "delete what was synced from my contacts" (D-064).

-- The app compares this with the version it needs and says clearly when the
-- server needs an update (instead of quietly working around it).
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 13 $$;
grant execute on function public.schema_version() to anon, authenticated;

-- Remove the hashed numbers I uploaded (settings button, or when I take
-- away the contacts permission). Existing connections stay.
create or replace function public.clear_contact_hashes()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  delete from contact_hashes where owner = auth.uid();
end;
$$;
revoke all on function public.clear_contact_hashes() from public, anon;
grant execute on function public.clear_contact_hashes() to authenticated;

insert into public.drivetalk_migrations (name)
values ('20261013000000_schema_contacts') on conflict do nothing;
