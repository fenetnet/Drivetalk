-- DriveTalk — background notifications whenever I'm free (not only driving).
-- The phone's small background service (same device token as the driving
-- feature) can now also end my availability from the notification's
-- "Stop" button, without opening the app.

create or replace function public.device_stop(p_token text)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
begin
  if me is null then return 'bad_token'; end if;
  delete from availability where user_id = me;
  update match_offers set status = 'cancelled', updated_at = now()
  where status = 'pending' and me in (user_a, user_b);
  return 'stopped';
end;
$$;
grant execute on function public.device_stop(text) to anon, authenticated;

-- Applied-migrations log, used by the automatic deploy (GitHub Actions).
create table if not exists public.drivetalk_migrations (
  name text primary key,
  applied_at timestamptz not null default now()
);
alter table public.drivetalk_migrations enable row level security;
revoke all on public.drivetalk_migrations from anon, authenticated;
