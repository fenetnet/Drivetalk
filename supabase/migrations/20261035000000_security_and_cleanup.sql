-- DriveBond — security fixes and automatic cleanup (D-110).
--
-- 1. Helper checks used by the privacy rules can no longer be asked
--    directly about other people ("is X free", "did X block me",
--    "are A and B friends"). They move to a private schema; the rules keep
--    using them (unchanged), and server functions call them through
--    internal copies the app can't reach.
--    NOTE for future migrations: a NEW policy must call private.<helper>;
--    server functions keep calling public.<helper> as before.
-- 2. A phone number is released only while the two are still connected.
-- 3. Reports, feedback and crash notes: per-person limits, and a shared
--    cap for brand-new accounts, so the owner's inbox can't be flooded.
-- 4. Owner code: only a per-account limit (others can't lock the owner
--    out), checked under a lock; too many tries says so.
-- 5. Cleanup every night: old activity records, old offers (the last talk
--    of each pair is kept), and short-lived bookkeeping rows.

-- ------------------------------------------------------------ 1. helpers

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

do $$
declare
  f record;
  args text;
  call_args text;
begin
  for f in
    select p.oid, p.proname,
           pg_get_function_arguments(p.oid) as fargs,
           pg_get_function_identity_arguments(p.oid) as iargs,
           pg_get_function_result(p.oid) as ret,
           p.pronargs
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('are_connected', 'is_blocked_between', 'awaits_approval',
                        'in_audience', 'is_anonymous', 'hides_call', 'hides_status',
                        'sees_availability', 'replaced_for', 'can_see_avatar')
  loop
    -- Already moved (pasted twice): nothing to do.
    continue when exists (
      select 1 from pg_proc q join pg_namespace m on m.oid = q.pronamespace
      where m.nspname = 'private' and q.proname = f.proname);
    -- Same function (policies keep pointing at it), new home.
    execute format('alter function public.%I(%s) set schema private', f.proname, f.iargs);
    select string_agg('$' || i, ', ') into call_args from generate_series(1, f.pronargs) i;
    -- Internal copy under the old name, for server functions only.
    execute format(
      'create function public.%I(%s) returns %s language sql stable security definer '
      'set search_path = '''' as $w$ select private.%I(%s) $w$',
      f.proname, f.fargs, f.ret, f.proname, coalesce(call_args, ''));
    execute format('revoke all on function public.%I(%s) from public, anon, authenticated',
                   f.proname, f.iargs);
  end loop;
end;
$$;

-- Used only by server functions.
revoke all on function public.replaced_account(uuid) from public, anon, authenticated;

-- --------------------------------------------- 2. numbers only for friends

create or replace function public.call_phone_for(o match_offers, p_me uuid)
returns text language sql stable security definer set search_path = public as $$
  select phone from phone_numbers
  where user_id = case when p_me = o.user_a then o.user_b else o.user_a end
    and are_connected(o.user_a, o.user_b)
    and not is_blocked_between(o.user_a, o.user_b);
$$;
revoke all on function public.call_phone_for(match_offers, uuid) from public, anon, authenticated;

-- ------------------------------------------------------- 3. flood limits

-- Brand-new accounts (under a day old) share one hourly cap per kind.
create or replace function public.new_account_flood(p_kind text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare
  since timestamptz := now() - interval '1 hour';
  young timestamptz := now() - interval '1 day';
  n integer;
begin
  if not exists (select 1 from profiles where id = auth.uid() and created_at > young) then
    return false;
  end if;
  if p_kind = 'reports' then
    select count(*) into n from reports r join profiles p on p.id = r.reporter
    where r.created_at > since and p.created_at > young;
    return n >= 30;
  elsif p_kind = 'feedback' then
    select count(*) into n from feedback_notes f join profiles p on p.id = f.user_id
    where f.created_at > since and p.created_at > young;
    return n >= 30;
  elsif p_kind = 'crash' then
    select count(*) into n from crash_reports c join profiles p on p.id = c.user_id
    where c.created_at > since and p.created_at > young;
    return n >= 50;
  end if;
  return false;
end;
$$;
revoke all on function public.new_account_flood(text) from public, anon, authenticated;

-- Reports: the same report twice a day counts once; up to 20 a day each.
-- (Extra ones are quietly dropped — the reporter already did their part.)
create or replace function public.reports_limit()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform pg_advisory_xact_lock(hashtext('reports'), hashtext(new.reporter::text));
  if exists (select 1 from reports
             where reporter = new.reporter and reported = new.reported
               and reason is not distinct from new.reason
               and created_at > now() - interval '1 day')
     or (select count(*) from reports
         where reporter = new.reporter and created_at > now() - interval '1 day') >= 20
     or new_account_flood('reports') then
    return null;
  end if;
  return new;
end;
$$;
revoke all on function public.reports_limit() from public, anon, authenticated;
drop trigger if exists reports_limit on public.reports;
create trigger reports_limit before insert on public.reports
  for each row execute function public.reports_limit();

create or replace function public.send_feedback(p_body text, p_build integer default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if (select count(*) from feedback_notes
      where user_id = auth.uid() and created_at > now() - interval '1 hour') >= 10
     or new_account_flood('feedback') then
    raise exception 'rate_limited';
  end if;
  insert into feedback_notes (user_id, body, app_build) values (auth.uid(), btrim(p_body), p_build);
end;
$$;

create or replace function public.report_crash(p_build text, p_kind text, p_message text, p_stack text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if (select count(*) from crash_reports
      where user_id = auth.uid() and created_at > now() - interval '1 day') >= 20
     or new_account_flood('crash') then
    return;
  end if;
  insert into crash_reports (user_id, build, kind, message, stack)
  values (auth.uid(), left(p_build, 40), left(p_kind, 40), left(p_message, 500),
          left(p_stack, 4000));
end;
$$;

-- The owner sees more of the latest reports.
create or replace function public.owner_reports()
returns table(created_at timestamptz, reporter text, reported text, reason text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_owner() then raise exception 'not_owner'; end if;
  return query
    select r.created_at, coalesce(a.display_name, '—'), coalesce(b.display_name, '—'), r.reason
    from reports r
    left join profiles a on a.id = r.reporter
    left join profiles b on b.id = r.reported
    order by r.created_at desc limit 300;
end;
$$;

-- ----------------------------------------------------------- 4. owner code

create or replace function public.claim_owner(p_code text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  -- One attempt at a time per account, so the count can't be raced.
  perform pg_advisory_xact_lock(hashtext('claim_owner'), hashtext(me::text));
  if (select count(*) from owner_claims where user_id = me and at > now() - interval '1 hour') >= 5 then
    raise exception 'rate_limited';
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

-- ------------------------------------------------------------ 5. cleanup

create or replace function public.nightly_cleanup()
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from app_events where created_at < now() - interval '90 days';
  delete from crash_reports where created_at < now() - interval '90 days';
  -- Old offers, except each pair's last talk ("last talked …").
  delete from match_offers o
  where o.created_at < now() - interval '90 days'
    and o.status <> 'pending'
    and not (coalesce(o.talked, false) and o.accepted_at = (
      select max(x.accepted_at) from match_offers x
      where x.user_a = o.user_a and x.user_b = o.user_b and x.talked));
  delete from contact_searches where at < now() - interval '2 days';
  delete from owner_claims where at < now() - interval '1 day';
  delete from pair_snoozes where until < now() - interval '1 day';
  delete from talk_intents where expires_at < now() - interval '1 day';
  delete from invitations where expires_at < now() - interval '30 days';
end;
$$;
revoke all on function public.nightly_cleanup() from public, anon, authenticated;

do $$
begin
  perform cron.schedule('drivetalk-nightly-cleanup', '17 3 * * *', 'select public.nightly_cleanup()');
exception when others then
  raise notice 'pg_cron not available: %', sqlerrm;
end;
$$;

-- Last: the version says 35 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 35 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261035000000_security_and_cleanup') on conflict do nothing;
