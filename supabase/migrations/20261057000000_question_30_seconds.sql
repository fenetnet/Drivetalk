-- DriveBond — a question is open for 30 seconds, not 2 minutes (D-139).
--
-- The owner: whoever asks waits 30 seconds; after that it's clear the other
-- one isn't available. Every new question (asked, or made because two
-- friends are free) now closes after 35 seconds on the server — the 5
-- extra let the asker's own "no answer" come first. The notification on the
-- other phone goes with it. Quick connect keeps its own timing.
-- (Older apps: their 25-second wait ends before this; nothing breaks.)

create or replace function public.question_short()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.status = 'pending' and not coalesce(new.quick, false) then
    new.expires_at := least(new.expires_at, now() + interval '35 seconds');
  end if;
  return new;
end;
$$;
revoke all on function public.question_short() from public, anon, authenticated;

drop trigger if exists match_offers_short on public.match_offers;
create trigger match_offers_short before insert on public.match_offers
  for each row execute function public.question_short();

-- Last: the version says 57 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 57 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261057000000_question_30_seconds') on conflict do nothing;
