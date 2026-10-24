-- DriveBond — more push notifications (D-120).
--
-- Events are queued in push_outbox by the database itself; the push server
-- function sends whatever is queued whenever any phone asks it to "flush"
-- (right after its own action). Sending twice is impossible: a row is
-- claimed once. Only the server function reads the queue.
-- - "sync": a question or an agreed call for me — my phone fetches it and
--   shows it, even if the app or its background service is closed.
-- - "owner": for the app's owners: new feedback, a crash, a new user.
-- - "version" is sent by the function itself (a new build on Google Play).

create table if not exists public.push_outbox (
  id bigserial primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null,
  data jsonb not null default '{}'::jsonb,
  dedupe text unique,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);
create index if not exists push_outbox_unsent on public.push_outbox (created_at) where sent_at is null;
alter table public.push_outbox enable row level security;
revoke all on public.push_outbox from public, anon, authenticated;
grant select, insert, update, delete on public.push_outbox to service_role;

-- Which build each phone runs (the "new version" note skips phones that
-- already have it), and the last build announced.
alter table public.push_tokens add column if not exists build integer;
create table if not exists public.push_state (
  key text primary key,
  value text,
  updated_at timestamptz not null default now()
);
alter table public.push_state enable row level security;
revoke all on public.push_state from public, anon, authenticated;
grant select, insert, update, delete on public.push_state to service_role;

-- Queue one note (quietly skipped when already queued under that key).
create or replace function public.push_queue(p_user uuid, p_kind text, p_data jsonb, p_dedupe text)
returns void language sql security definer set search_path = public as $$
  insert into push_outbox (user_id, kind, data, dedupe)
  select p_user, p_kind, coalesce(p_data, '{}'::jsonb), p_dedupe
  where exists (select 1 from push_tokens t where t.user_id = p_user)
  on conflict (dedupe) do nothing;
$$;
revoke all on function public.push_queue(uuid, text, jsonb, text) from public, anon, authenticated;

-- A new question for me, or a call agreed: my phone fetches and shows it.
create or replace function public.offer_push()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' and new.status = 'pending' then
    -- The one who tapped already said yes: only the other side is asked.
    if new.a_response is distinct from 'accept' then
      perform push_queue(new.user_a, 'sync', '{}'::jsonb, 'offer:' || new.id || ':' || new.user_a);
    end if;
    if new.b_response is distinct from 'accept' then
      perform push_queue(new.user_b, 'sync', '{}'::jsonb, 'offer:' || new.id || ':' || new.user_b);
    end if;
  elsif tg_op = 'UPDATE' and new.status = 'accepted' and old.status is distinct from 'accepted' then
    perform push_queue(new.user_a, 'sync', '{}'::jsonb, 'call:' || new.id || ':' || new.user_a);
    perform push_queue(new.user_b, 'sync', '{}'::jsonb, 'call:' || new.id || ':' || new.user_b);
  end if;
  return null;
end;
$$;
revoke all on function public.offer_push() from public, anon, authenticated;
drop trigger if exists offer_push on public.match_offers;
create trigger offer_push after insert or update of status on public.match_offers
  for each row execute function public.offer_push();

-- For the owners: feedback, crashes (at most one note an hour), new users.
create or replace function public.owner_push()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  what text := case tg_table_name
    when 'feedback_notes' then 'feedback'
    when 'crash_reports' then 'crash'
    else 'user' end;
  hour text := to_char(now() at time zone 'UTC', 'YYYYMMDDHH24');
  o record;
begin
  for o in select user_id from app_owners loop
    perform push_queue(
      o.user_id, 'owner',
      jsonb_build_object('what', what,
        'name', case when what = 'user' then to_jsonb(new)->>'display_name' else '' end),
      case when what = 'crash' then 'owner:crash:' || hour || ':' || o.user_id
           else 'owner:' || what || ':' || new.id || ':' || o.user_id end);
  end loop;
  return null;
end;
$$;
revoke all on function public.owner_push() from public, anon, authenticated;
drop trigger if exists owner_push on public.feedback_notes;
create trigger owner_push after insert on public.feedback_notes
  for each row execute function public.owner_push();
drop trigger if exists owner_push on public.crash_reports;
create trigger owner_push after insert on public.crash_reports
  for each row execute function public.owner_push();
drop trigger if exists owner_push on public.profiles;
create trigger owner_push after insert on public.profiles
  for each row execute function public.owner_push();

-- The server function takes what's queued (each row once) and sends it.
create or replace function public.push_outbox_claim()
returns table (id bigint, kind text, data jsonb, push_token text)
language plpgsql security definer set search_path = public as $$
begin
  -- Too old to matter any more.
  update push_outbox o set sent_at = now()
  where o.sent_at is null and o.created_at < now() - interval '10 minutes';
  return query
  with taken as (
    update push_outbox o set sent_at = now()
    where o.id in (select x.id from push_outbox x
                   where x.sent_at is null
                   order by x.id limit 200
                   for update skip locked)
    returning o.id, o.user_id, o.kind, o.data
  )
  select taken.id, taken.kind, taken.data, t.token
  from taken join push_tokens t on t.user_id = taken.user_id;
end;
$$;
revoke all on function public.push_outbox_claim() from public, anon, authenticated;
grant execute on function public.push_outbox_claim() to service_role;

-- This phone's push address, now with the build it runs. (Replaces the
-- one-argument version: older apps calling with only p_token still match.)
drop function if exists public.save_push_token(text);
create or replace function public.save_push_token(p_token text, p_build integer default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_token is null or length(p_token) < 20 or length(p_token) > 4096 then return; end if;
  insert into push_tokens (token, user_id, build) values (p_token, me, p_build)
  on conflict (token) do update
    set user_id = excluded.user_id, updated_at = now(),
        build = coalesce(excluded.build, push_tokens.build);
  delete from push_tokens t
  where t.user_id = me
    and t.token not in (select token from push_tokens where user_id = me
                        order by updated_at desc limit 5);
end;
$$;
revoke all on function public.save_push_token(text, integer) from public, anon;
grant execute on function public.save_push_token(text, integer) to authenticated;

-- "A new version": phones that don't have [p_build] yet, at most once a day
-- per phone. Called by the push server function only.
create or replace function public.version_push_claim(p_build integer)
returns table (push_token text)
language plpgsql security definer set search_path = public as $$
declare
  last text;
begin
  select value into last from push_state where key = 'version_announced';
  if last is not null and last::integer >= p_build then return; end if;
  insert into push_state (key, value) values ('version_announced', p_build::text)
  on conflict (key) do update set value = excluded.value, updated_at = now();
  return query
  update push_tokens t set updated_at = t.updated_at
  where (t.build is null or t.build < p_build)
    and not exists (select 1 from push_state s
                    where s.key = 'version_told:' || t.token
                      and s.updated_at > now() - interval '20 hours')
  returning t.token;
  insert into push_state (key, value)
  select 'version_told:' || t.token, p_build::text from push_tokens t
  where t.build is null or t.build < p_build
  on conflict (key) do update set value = excluded.value, updated_at = now();
end;
$$;
revoke all on function public.version_push_claim(integer) from public, anon, authenticated;
grant execute on function public.version_push_claim(integer) to service_role;

-- Last: the version says 46 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 46 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261046000000_push_events') on conflict do nothing;
