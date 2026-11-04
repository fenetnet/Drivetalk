-- DriveTalk — the owner reads feedback and reports inside the app (D-080).
--
-- Entering the owner's code in the app ("Admin") also registers that account
-- on the server as an owner (the server checks the code's SHA-256; the code
-- itself is in neither the app nor here). Only owners can read the notes.

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 21 $$;
grant execute on function public.schema_version() to anon, authenticated;

create table if not exists public.app_owners (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.app_owners enable row level security;
revoke all on public.app_owners from anon, authenticated;

create table if not exists public.owner_claims (
  user_id uuid not null,
  at timestamptz not null default now()
);
alter table public.owner_claims enable row level security;
revoke all on public.owner_claims from anon, authenticated;

create or replace function public.is_owner()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from app_owners where user_id = auth.uid());
$$;
revoke all on function public.is_owner() from public, anon;
grant execute on function public.is_owner() to authenticated;

-- At most 5 tries an hour per account.
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
  if encode(extensions.digest('drivetalk-admin:' || btrim(coalesce(p_code, '')), 'sha256'), 'hex')
     <> '5b054ffe210bfa737ef580c8bbcce8ffac40785b71306fc8cac11a89cb851d73' then
    return false;
  end if;
  insert into app_owners (user_id) values (me) on conflict do nothing;
  return true;
end;
$$;
revoke all on function public.claim_owner(text) from public, anon;
grant execute on function public.claim_owner(text) to authenticated;

-- Latest feedback (owner only).
create or replace function public.owner_feedback()
returns table (created_at timestamptz, display_name text, body text, app_build integer)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_owner() then raise exception 'not_owner'; end if;
  return query
    select f.created_at, coalesce(p.display_name, '—'), f.body, f.app_build
    from feedback_notes f left join profiles p on p.id = f.user_id
    order by f.created_at desc limit 100;
end;
$$;
revoke all on function public.owner_feedback() from public, anon;
grant execute on function public.owner_feedback() to authenticated;

-- Latest reports (owner only).
create or replace function public.owner_reports()
returns table (created_at timestamptz, reporter text, reported text, reason text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_owner() then raise exception 'not_owner'; end if;
  return query
    select r.created_at, coalesce(a.display_name, '—'), coalesce(b.display_name, '—'), r.reason
    from reports r
    left join profiles a on a.id = r.reporter
    left join profiles b on b.id = r.reported
    order by r.created_at desc limit 100;
end;
$$;
revoke all on function public.owner_reports() from public, anon;
grant execute on function public.owner_reports() to authenticated;

insert into public.drivetalk_migrations (name)
values ('20261021000000_owner_inbox') on conflict do nothing;
