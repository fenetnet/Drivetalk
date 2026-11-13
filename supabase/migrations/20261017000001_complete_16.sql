-- DriveTalk — completes server update 16 when only 17 was added.
-- Safe to run more than once, before or after 17.

create or replace function public.asked_enough(p_user uuid, p_since timestamptz)
returns boolean language sql stable security definer set search_path = public as $$
  select count(*) >= 3 from match_offers o
  where p_user in (o.user_a, o.user_b)
    and not o.quick
    and o.created_at >= p_since
    and o.status in ('declined', 'expired', 'cancelled');
$$;
revoke all on function public.asked_enough(uuid, timestamptz) from public, anon, authenticated;

-- Numbers that are not a DriveTalk user's are not kept.
delete from public.contact_hashes c
where not exists (select 1 from public.phone_numbers pn where pn.phone_hash = c.hash);

insert into public.drivetalk_migrations (name)
values ('20261016000000_less_noise_no_phonebook') on conflict do nothing;
