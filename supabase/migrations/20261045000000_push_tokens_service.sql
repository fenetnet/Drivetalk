-- DriveBond — the push server function may read push addresses (D-119).
--
-- On the hosted server the service role didn't get access to the new
-- push_tokens table, so the test notification failed with "permission
-- denied for table push_tokens". Only the server function uses the
-- service role; apps still can't read the table.

grant select, delete on public.push_tokens to service_role;
grant select, insert, update, delete on public.trip_pushes to service_role;

-- Last: the version says 45 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 45 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261045000000_push_tokens_service') on conflict do nothing;
