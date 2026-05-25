create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text not null default '',
  role text not null default 'worker',
  created_by uuid null references public.profiles (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.profiles
  add column if not exists email text,
  add column if not exists full_name text not null default '',
  add column if not exists role text not null default 'worker',
  add column if not exists created_by uuid null references public.profiles (id) on delete set null,
  add column if not exists created_at timestamptz not null default timezone('utc', now()),
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_role_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_role_check check (role in ('worker', 'admin'));
  end if;
end $$;

create index if not exists profiles_role_idx on public.profiles (role);
create index if not exists profiles_email_idx on public.profiles (lower(email));

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, role, created_at, updated_at)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    case
      when coalesce(new.raw_user_meta_data ->> 'role', new.raw_app_meta_data ->> 'kasudlo_role') = 'admin'
        then 'admin'
      else 'worker'
    end,
    coalesce(new.created_at, timezone('utc', now())),
    timezone('utc', now())
  )
  on conflict (id) do update
  set email = excluded.email,
      full_name = case
        when excluded.full_name <> '' then excluded.full_name
        else public.profiles.full_name
      end,
      updated_at = timezone('utc', now());

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function public.handle_new_user_profile();

insert into public.profiles (id, email, full_name, role, created_at, updated_at)
select
  users.id,
  coalesce(users.email, ''),
  coalesce(users.raw_user_meta_data ->> 'full_name', ''),
  'worker',
  coalesce(users.created_at, timezone('utc', now())),
  timezone('utc', now())
from auth.users as users
on conflict (id) do update
set email = excluded.email,
    updated_at = timezone('utc', now());

update public.profiles set email = '' where email is null;
alter table public.profiles alter column email set not null;

create or replace function public.is_kasudlo_admin(p_user_id uuid default auth.uid())
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
      and role = 'admin'
  );
$$;

revoke all on function public.is_kasudlo_admin(uuid) from public;
grant execute on function public.is_kasudlo_admin(uuid) to authenticated, service_role;

alter table public.profiles enable row level security;

drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin
on public.profiles
for select
to authenticated
using (auth.uid() = id or public.is_kasudlo_admin(auth.uid()));

create table if not exists public.admin_account_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid null references auth.users (id) on delete set null,
  target_user_id uuid null references auth.users (id) on delete set null,
  target_email text not null,
  target_role text not null check (target_role in ('worker', 'admin')),
  action text not null default 'create_user',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists admin_account_events_actor_idx
  on public.admin_account_events (actor_user_id, created_at desc);

create index if not exists admin_account_events_target_idx
  on public.admin_account_events (target_user_id, created_at desc);

alter table public.admin_account_events enable row level security;

drop policy if exists admin_account_events_select_admin on public.admin_account_events;
create policy admin_account_events_select_admin
on public.admin_account_events
for select
to authenticated
using (public.is_kasudlo_admin(auth.uid()));

grant select on public.profiles to authenticated;
grant select on public.admin_account_events to authenticated;

create table if not exists public.household_assessments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  client_submission_id text not null,
  respondent_name text not null,
  respondent_age integer null check (respondent_age is null or respondent_age >= 0),
  address text not null,
  family_members_count integer not null default 0 check (family_members_count >= 0),
  family_members jsonb not null default '[]'::jsonb,
  health_problems text[] not null default '{}'::text[],
  vaccination_status text not null default '',
  water_sanitation text not null default '',
  nutritional_status text not null default '',
  community_concerns text[] not null default '{}'::text[],
  consent_given boolean not null default false,
  notes text not null default '',
  payload jsonb not null default '{}'::jsonb,
  submitted_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id, client_submission_id)
);

create index if not exists household_assessments_user_created_idx
  on public.household_assessments (user_id, created_at desc);

create index if not exists household_assessments_submitted_idx
  on public.household_assessments (submitted_at desc);

drop trigger if exists household_assessments_set_updated_at
  on public.household_assessments;
create trigger household_assessments_set_updated_at
before update on public.household_assessments
for each row execute function public.set_updated_at();

alter table public.household_assessments enable row level security;

drop policy if exists household_assessments_select_own_or_admin
  on public.household_assessments;
create policy household_assessments_select_own_or_admin
on public.household_assessments
for select
to authenticated
using (auth.uid() = user_id or public.is_kasudlo_admin(auth.uid()));

drop policy if exists household_assessments_insert_own
  on public.household_assessments;
create policy household_assessments_insert_own
on public.household_assessments
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists household_assessments_update_own
  on public.household_assessments;
create policy household_assessments_update_own
on public.household_assessments
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists household_assessments_delete_own
  on public.household_assessments;
create policy household_assessments_delete_own
on public.household_assessments
for delete
to authenticated
using (auth.uid() = user_id);

grant select, insert, update, delete on public.household_assessments
  to authenticated;

create or replace function public.kasudlo_jsonb_text_array(p_value jsonb)
returns text[]
language sql
immutable
set search_path = public
as $$
  select coalesce(array_agg(item), '{}'::text[])
  from jsonb_array_elements_text(
    case
      when jsonb_typeof(p_value) = 'array' then p_value
      else '[]'::jsonb
    end
  ) as items(item);
$$;

create or replace function public.kasudlo_submit_household_assessment(
  payload jsonb,
  p_client_submission_id text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_assessment_id uuid;
  v_family_members jsonb;
begin
  if v_user_id is null then
    raise exception 'Sign in before submitting an assessment.';
  end if;

  if coalesce(nullif(trim(p_client_submission_id), ''), '') = '' then
    raise exception 'Client submission id is required.';
  end if;

  v_family_members := case
    when jsonb_typeof(payload -> 'family_members') = 'array'
      then payload -> 'family_members'
    else '[]'::jsonb
  end;

  insert into public.household_assessments (
    user_id,
    client_submission_id,
    respondent_name,
    respondent_age,
    address,
    family_members_count,
    family_members,
    health_problems,
    vaccination_status,
    water_sanitation,
    nutritional_status,
    community_concerns,
    consent_given,
    notes,
    payload,
    submitted_at
  )
  values (
    v_user_id,
    trim(p_client_submission_id),
    coalesce(nullif(trim(payload ->> 'respondent_name'), ''), 'Unnamed respondent'),
    nullif(payload ->> 'respondent_age', '')::integer,
    coalesce(nullif(trim(payload ->> 'address'), ''), ''),
    greatest(coalesce(nullif(payload ->> 'family_members_count', '')::integer, 0), 0),
    v_family_members,
    public.kasudlo_jsonb_text_array(payload -> 'health_problems'),
    coalesce(payload ->> 'vaccination_status', ''),
    coalesce(payload ->> 'water_sanitation', ''),
    coalesce(payload ->> 'nutritional_status', ''),
    public.kasudlo_jsonb_text_array(payload -> 'community_concerns'),
    coalesce((payload ->> 'consent_given')::boolean, false),
    coalesce(payload ->> 'notes', ''),
    coalesce(payload, '{}'::jsonb),
    timezone('utc', now())
  )
  on conflict (user_id, client_submission_id) do update
  set respondent_name = excluded.respondent_name,
      respondent_age = excluded.respondent_age,
      address = excluded.address,
      family_members_count = excluded.family_members_count,
      family_members = excluded.family_members,
      health_problems = excluded.health_problems,
      vaccination_status = excluded.vaccination_status,
      water_sanitation = excluded.water_sanitation,
      nutritional_status = excluded.nutritional_status,
      community_concerns = excluded.community_concerns,
      consent_given = excluded.consent_given,
      notes = excluded.notes,
      payload = excluded.payload,
      submitted_at = timezone('utc', now())
  returning id into v_assessment_id;

  return v_assessment_id;
end;
$$;

revoke all on function public.kasudlo_jsonb_text_array(jsonb) from public;
revoke all on function public.kasudlo_submit_household_assessment(jsonb, text)
  from public;
grant execute on function public.kasudlo_submit_household_assessment(jsonb, text)
  to authenticated;

-- First admin seed, to run manually after creating/signing in the initial account:
-- update public.profiles set role = 'admin' where email = 'admin@example.com';
