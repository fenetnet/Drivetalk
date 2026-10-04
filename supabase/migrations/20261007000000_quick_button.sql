-- DriveTalk — one-tap "I'm free" from the home-screen widget and the
-- quick-settings tile, without opening the app (same device token).

create or replace function public.device_start(
  p_token text, p_mode text default 'free', p_minutes integer default 30)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
  mins integer := least(greatest(coalesce(p_minutes, 30), 1), 180);
  until timestamptz;
begin
  if me is null then return null; end if;
  if p_mode not in ('driving', 'walking', 'breakTime', 'free') then
    p_mode := 'free';
  end if;
  until := now() + make_interval(mins => mins);
  insert into availability (user_id, mode, started_at, expires_at, source)
  values (me, p_mode, now(), until, 'manual')
  on conflict (user_id) do update
    set mode = excluded.mode, started_at = now(), expires_at = until,
        source = 'manual', circle_id = null;
  update profiles set last_seen_at = now() where id = me;
  perform create_offers_for(me);
  return until;
end;
$$;

-- Token → user without touching last_used_at (for read-only checks).
create or replace function public.device_user_readonly(p_token text)
returns uuid language sql stable security definer set search_path = public, extensions as $$
  select user_id from device_tokens
  where p_token is not null and length(p_token) >= 30
    and token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
$$;

-- Am I free right now? (null = no)
create or replace function public.device_status(p_token text)
returns timestamptz language sql stable security definer set search_path = public as $$
  select a.expires_at from availability a
  where a.user_id = public.device_user_readonly(p_token) and a.expires_at > now();
$$;

revoke all on function public.device_user_readonly(text) from public, anon, authenticated;
grant execute on function public.device_start(text, text, integer) to anon, authenticated;
grant execute on function public.device_status(text) to anon, authenticated;
