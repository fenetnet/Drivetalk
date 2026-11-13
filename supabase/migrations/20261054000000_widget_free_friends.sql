-- DriveBond — the "who's free now" home-screen widget (D-133).
--
-- The widget refreshes itself when the app is closed (a push, or every 30
-- minutes) with the phone's device token, like the background service.
-- It gets exactly what the app would show: friends who are free now and
-- whom I may see by name (the same rules as the availability policy),
-- with the mode and until when. Never a number, a place or a group.

create or replace function public.device_free_friends(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
begin
  if me is null then return '[]'::jsonb; end if;
  if is_anonymous(me) then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(x order by x->>'busy', x->>'until' desc)
    from (
      select jsonb_build_object(
        'id', a.user_id,
        'name', p.display_name,
        'mode', a.mode,
        'until', a.expires_at,
        'busy', coalesce(a.call_until > now() or a.phone_until > now(), false)) as x
      from availability a
      join profiles p on p.id = a.user_id
      where a.user_id <> me
        and sees_free_apart_from_name(me, a)
        and not is_anonymous(a.user_id)
      limit 10
    ) t), '[]'::jsonb);
end;
$$;
revoke all on function public.device_free_friends(text) from public;
grant execute on function public.device_free_friends(text) to anon, authenticated;

-- Last: the version says 54 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 54 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261054000000_widget_free_friends') on conflict do nothing;
