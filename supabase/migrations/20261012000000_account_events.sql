-- DriveTalk — delete my account, a few anonymous-ish measurements, and an
-- all-or-nothing circle save (D-063).

-- "Delete my account and my information": everything that belongs to me
-- goes with the account (profile, number, contact hashes, connections,
-- availability, offers, device tokens, circles, intents, measurements).
-- My photo file is removed by the app first (storage API).
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public, auth as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  delete from public.profiles where id = me;
  delete from auth.users where id = me;
end;
$$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- Measurements: only event names and an optional duration (ms). No call
-- content, no numbers, no names. Readable only by the owner in Supabase.
create table if not exists public.app_events (
  id bigserial primary key,
  user_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  name text not null check (name ~ '^[a-z_]{3,40}$'),
  ms integer check (ms is null or ms between 0 and 86400000),
  created_at timestamptz not null default now()
);
create index if not exists app_events_name_idx on public.app_events (name, created_at);
alter table public.app_events enable row level security;
revoke all on public.app_events from anon, authenticated;

create or replace function public.log_event(p_name text, p_ms integer default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  if not exists (select 1 from profiles where id = auth.uid()) then return; end if;
  insert into app_events (user_id, name, ms) values (auth.uid(), p_name, p_ms);
end;
$$;
revoke all on function public.log_event(text, integer) from public, anon;
grant execute on function public.log_event(text, integer) to authenticated;

-- Save a circle in one go (no half-saved members).
create or replace function public.save_circle(
  p_id uuid, p_name text, p_quick boolean, p_members uuid[])
returns uuid language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  cid uuid := p_id;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if cid is null then
    insert into circles (owner, name, quick) values (me, btrim(p_name), p_quick)
    returning id into cid;
  else
    update circles set name = btrim(p_name), quick = p_quick
    where id = cid and owner = me;
    if not found then raise exception 'not_found'; end if;
  end if;
  delete from circle_members where circle_id = cid;
  insert into circle_members (circle_id, member)
  select cid, m from unnest(coalesce(p_members, '{}')) as m
  where are_connected(me, m) and not is_blocked_between(me, m)
  on conflict do nothing;
  return cid;
end;
$$;
revoke all on function public.save_circle(uuid, text, boolean, uuid[]) from public, anon;
grant execute on function public.save_circle(uuid, text, boolean, uuid[]) to authenticated;

insert into public.drivetalk_migrations (name)
values ('20261012000000_account_events') on conflict do nothing;
