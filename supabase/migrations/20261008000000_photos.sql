-- DriveTalk — profile photos in the real mode.
-- Private storage: a photo is visible only to its owner and their friends
-- (not to anyone blocked). One small JPEG per user, named "<user id>.jpg".

alter table public.profiles add column if not exists photo_version integer not null default 0;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 1048576, array['image/jpeg'])
on conflict (id) do nothing;

-- May the current user see the photo stored under this name?
create or replace function public.can_see_avatar(p_name text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  owner text := split_part(coalesce(p_name, ''), '.', 1);
  other uuid;
begin
  if me is null then return false; end if;
  if owner = me::text then return true; end if;
  begin
    other := owner::uuid;
  exception when others then
    return false;
  end;
  return are_connected(me, other) and not is_blocked_between(me, other);
end;
$$;
revoke all on function public.can_see_avatar(text) from public, anon;
grant execute on function public.can_see_avatar(text) to authenticated;

drop policy if exists avatars_select on storage.objects;
drop policy if exists avatars_insert on storage.objects;
drop policy if exists avatars_update on storage.objects;
drop policy if exists avatars_delete on storage.objects;

create policy avatars_select on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and public.can_see_avatar(name));
create policy avatars_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and name = auth.uid()::text || '.jpg');
create policy avatars_update on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and name = auth.uid()::text || '.jpg')
  with check (bucket_id = 'avatars' and name = auth.uid()::text || '.jpg');
create policy avatars_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and name = auth.uid()::text || '.jpg');

-- After uploading (true) or removing (false) my photo: bump the version so
-- friends' phones know to download the new one.
create or replace function public.set_photo(p_has boolean)
returns integer language sql security definer set search_path = public as $$
  update profiles
  set photo_version = case when p_has then photo_version + 1 else 0 end
  where id = auth.uid()
  returning photo_version;
$$;
revoke all on function public.set_photo(boolean) from public, anon;
grant execute on function public.set_photo(boolean) to authenticated;
