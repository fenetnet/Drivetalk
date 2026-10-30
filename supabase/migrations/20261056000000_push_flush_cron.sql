-- DriveBond — the server sends waiting notifications by itself (D-135).
--
-- Notifications are queued in push_outbox and went out only when some
-- phone called the push function after an action. A note nobody's action
-- followed (e.g. "X tried to reach you" when a question ran out at night)
-- waited, and after 10 minutes was dropped unsent. Now, once a minute, if
-- anything waits, the database calls the push function itself (pg_net).
--
-- The function's address is set once by the owner in the SQL editor (not
-- in git):  insert into private.push_flush_settings (id, url)
--           values (1, 'https://<project>.supabase.co/functions/v1/smooth-responder')
--           on conflict (id) do update set url = excluded.url;
-- No key is needed: the function's flush sends only what is already queued.
-- Without the address nothing changes (phones still ask after actions).

create extension if not exists pg_net;

create table if not exists private.push_flush_settings (
  id int primary key check (id = 1),
  url text not null check (url like 'https://%')
);
revoke all on private.push_flush_settings from public, anon, authenticated;

create or replace function private.push_flush_tick()
returns void language plpgsql security definer set search_path = public, private as $$
declare
  target text := (select url from private.push_flush_settings where id = 1);
begin
  if target is null then return; end if;
  if not exists (select 1 from push_outbox
                 where sent_at is null and created_at > now() - interval '10 minutes') then
    return;
  end if;
  perform net.http_post(
    url := target,
    body := '{"kind":"flush"}'::jsonb,
    headers := '{"Content-Type":"application/json"}'::jsonb);
end;
$$;
revoke all on function private.push_flush_tick() from public, anon, authenticated;

do $$
begin
  perform cron.unschedule('drivetalk-push-flush')
  where exists (select 1 from cron.job where jobname = 'drivetalk-push-flush');
  perform cron.schedule('drivetalk-push-flush', '* * * * *', 'select private.push_flush_tick()');
end;
$$;

-- Last: the version says 56 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 56 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261056000000_push_flush_cron') on conflict do nothing;
