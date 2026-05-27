-- 20260527000000_rename_worker_to_nurse_role.sql

-- Drop existing constraints
alter table public.profiles
  drop constraint if exists profiles_role_check;

do $$
declare
  v_constraint_name text;
begin
  for v_constraint_name in
    select constraints.conname
    from pg_constraint as constraints
    join pg_class as tables
      on tables.oid = constraints.conrelid
    join pg_namespace as namespaces
      on namespaces.oid = tables.relnamespace
    where namespaces.nspname = 'public'
      and tables.relname = 'admin_account_events'
      and constraints.contype = 'c'
      and pg_get_constraintdef(constraints.oid) like '%target_role%'
  loop
    execute format(
      'alter table public.admin_account_events drop constraint %I',
      v_constraint_name
    );
  end loop;
end $$;

-- Update existing records in tables
update public.profiles
set role = 'nurse'
where role = 'worker';

update public.admin_account_events
set target_role = 'nurse'
where target_role = 'worker';

set session_replication_role = 'replica';
update public.audit_logs
set actor_role = 'nurse'
where actor_role = 'worker';
set session_replication_role = 'origin';

-- Re-add constraints with 'nurse' instead of 'worker'
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('nurse', 'patient', 'admin'));

alter table public.admin_account_events
  add constraint admin_account_events_target_role_check
  check (target_role in ('nurse', 'patient', 'admin'));

-- Update handle_new_user_profile trigger function
create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := coalesce(
    new.raw_user_meta_data ->> 'role',
    new.raw_app_meta_data ->> 'kasudlo_role'
  );
begin
  insert into public.profiles (id, email, full_name, role, created_at, updated_at)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    case
      when v_role in ('admin', 'patient') then v_role
      else 'nurse'
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
