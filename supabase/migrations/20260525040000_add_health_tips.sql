create or replace function public.is_kasudlo_health_tip_manager(
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = p_user_id
      and role in ('worker', 'admin')
  );
$$;

revoke all on function public.is_kasudlo_health_tip_manager(uuid) from public;
grant execute on function public.is_kasudlo_health_tip_manager(uuid)
  to authenticated, service_role;

create table if not exists public.health_tips (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  file_name text not null default '',
  mime_type text not null default '',
  file_size integer not null default 0,
  attachment_base64 text not null default '',
  created_by uuid null references auth.users (id) on delete set null,
  created_by_email text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.health_tips
  add column if not exists title text not null default '',
  add column if not exists description text not null default '',
  add column if not exists file_name text not null default '',
  add column if not exists mime_type text not null default '',
  add column if not exists file_size integer not null default 0,
  add column if not exists attachment_base64 text not null default '',
  add column if not exists created_by uuid null references auth.users (id) on delete set null,
  add column if not exists created_by_email text not null default '',
  add column if not exists created_at timestamptz not null default timezone('utc', now()),
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

update public.health_tips
set title = 'Untitled health teaching'
where length(btrim(title)) = 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'health_tips_file_size_nonnegative'
      and conrelid = 'public.health_tips'::regclass
  ) then
    alter table public.health_tips
      add constraint health_tips_file_size_nonnegative
      check (file_size >= 0);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'health_tips_title_not_blank'
      and conrelid = 'public.health_tips'::regclass
  ) then
    alter table public.health_tips
      add constraint health_tips_title_not_blank
      check (length(btrim(title)) > 0);
  end if;
end $$;

create index if not exists health_tips_updated_at_idx
  on public.health_tips (updated_at desc);

create index if not exists health_tips_created_by_idx
  on public.health_tips (created_by);

drop trigger if exists health_tips_set_updated_at on public.health_tips;
create trigger health_tips_set_updated_at
before update on public.health_tips
for each row execute function public.set_updated_at();

alter table public.health_tips enable row level security;

drop policy if exists health_tips_select_authenticated
  on public.health_tips;
create policy health_tips_select_authenticated
on public.health_tips
for select
to authenticated
using (true);

drop policy if exists health_tips_insert_manager
  on public.health_tips;
create policy health_tips_insert_manager
on public.health_tips
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and (select public.is_kasudlo_health_tip_manager(auth.uid()))
);

drop policy if exists health_tips_update_manager
  on public.health_tips;
create policy health_tips_update_manager
on public.health_tips
for update
to authenticated
using ((select public.is_kasudlo_health_tip_manager(auth.uid())))
with check ((select public.is_kasudlo_health_tip_manager(auth.uid())));

drop policy if exists health_tips_delete_manager
  on public.health_tips;
create policy health_tips_delete_manager
on public.health_tips
for delete
to authenticated
using ((select public.is_kasudlo_health_tip_manager(auth.uid())));

grant select, insert, update, delete on public.health_tips
  to authenticated;
