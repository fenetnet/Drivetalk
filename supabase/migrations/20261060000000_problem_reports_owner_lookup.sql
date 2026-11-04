-- DriveBond — "report a problem" and the owner's "why is X grey?" (D-143).
--
-- 1. Feedback can carry the app's technical details (what the test tab
--    shows: versions, states, the phone's log — no names, no numbers, never
--    words from the voice), so a problem report says what happened.
-- 2. owner_lookup(name or number hash): for the owner only — a person's
--    state on the server: free or not, why they can't be asked, an open
--    call, a missed question, how many accounts share their number. Never
--    a number, a place or a group.

alter table public.feedback_notes add column if not exists diag text
  check (diag is null or char_length(diag) <= 6000);

-- One version with the details (older apps call it with two arguments).
drop function if exists public.send_feedback(text, integer);
create or replace function public.send_feedback(
  p_body text, p_build integer default null, p_diag text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if (select count(*) from feedback_notes
      where user_id = auth.uid() and created_at > now() - interval '1 hour') >= 10
     or new_account_flood('feedback') then
    raise exception 'rate_limited';
  end if;
  insert into feedback_notes (user_id, body, app_build, diag)
  values (auth.uid(), btrim(p_body), p_build, left(p_diag, 6000));
end;
$$;
revoke all on function public.send_feedback(text, integer, text) from public, anon;
grant execute on function public.send_feedback(text, integer, text) to authenticated;

create or replace function public.owner_feedback_details()
returns table (created_at timestamptz, display_name text, body text,
               app_build integer, diag text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_owner() then raise exception 'not_owner'; end if;
  return query
    select f.created_at, coalesce(p.display_name, '—'), f.body, f.app_build, f.diag
    from feedback_notes f left join profiles p on p.id = f.user_id
    order by f.created_at desc limit 100;
end;
$$;
revoke all on function public.owner_feedback_details() from public, anon;
grant execute on function public.owner_feedback_details() to authenticated;

create or replace function public.owner_lookup(p_query text)
returns table (
  user_id uuid, display_name text, last_seen_at timestamptz,
  same_number_accounts integer, friends integer,
  free_mode text, free_until timestamptz, free_source text,
  missed_at timestamptz, quiet_until timestamptz,
  in_call boolean, on_phone boolean, open_question boolean,
  asked_enough boolean, can_be_asked boolean, auto_driving boolean,
  last_offer text)
language plpgsql stable security definer set search_path = public as $$
declare
  q text := btrim(coalesce(p_query, ''));
begin
  if not is_owner() then raise exception 'not_owner'; end if;
  if char_length(q) < 2 then return; end if;
  return query
    select p.id, p.display_name, p.last_seen_at,
      (select count(*)::int from same_number_accounts(p.id)),
      (select count(*)::int from connections c
       where (c.user_a = p.id or c.user_b = p.id) and c.pending_for is null),
      a.mode::text, a.expires_at, a.source::text,
      a.missed_at, a.quiet_until,
      public.in_call(p.id), public.on_phone(p.id), public.has_open_offer(p.id),
      case when a.user_id is null then null
           else public.asked_enough(p.id, a.started_at) end,
      public.can_be_asked(p.id),
      exists (select 1 from device_tokens d where d.user_id = p.id),
      (select o.status || ' ' || to_char(o.updated_at at time zone 'Asia/Jerusalem', 'DD/MM HH24:MI')
       from match_offers o where p.id in (o.user_a, o.user_b)
       order by o.updated_at desc limit 1)
    from profiles p
    left join availability a on a.user_id = p.id and a.expires_at > now()
    where p.display_name ilike '%' || q || '%'
       or (q ~ '^[0-9a-f]{64}$' and exists (
             select 1 from phone_numbers n where n.user_id = p.id and n.phone_hash = q))
    order by p.last_seen_at desc nulls last
    limit 20;
end;
$$;
revoke all on function public.owner_lookup(text) from public, anon;
grant execute on function public.owner_lookup(text) to authenticated;

-- Last: the version says 60 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 60 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261060000000_problem_reports_owner_lookup') on conflict do nothing;
