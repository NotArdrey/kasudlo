alter table public.health_tips
  add column if not exists target_patient_id uuid null references auth.users (id) on delete set null;

create index if not exists health_tips_target_patient_idx
  on public.health_tips (target_patient_id);

alter table public.health_tips
  add column if not exists target_patient_ids uuid[] not null default '{}'::uuid[];

update public.health_tips
set target_patient_ids = array[target_patient_id]
where target_patient_id is not null
  and coalesce(array_length(target_patient_ids, 1), 0) = 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'health_tips_target_patient_ids_no_nulls'
      and conrelid = 'public.health_tips'::regclass
  ) then
    alter table public.health_tips
      add constraint health_tips_target_patient_ids_no_nulls
      check (array_position(target_patient_ids, null) is null);
  end if;
end $$;

create index if not exists health_tips_target_patient_ids_idx
  on public.health_tips using gin (target_patient_ids);

create or replace function public.kasudlo_list_health_tip_patients()
returns table (
  id uuid,
  email text,
  full_name text,
  role text,
  created_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select
    profiles.id,
    profiles.email,
    profiles.full_name,
    profiles.role,
    profiles.created_at
  from public.profiles
  where profiles.role = 'patient'
    and (select public.is_kasudlo_health_tip_manager(auth.uid()))
  order by profiles.created_at desc;
$$;

revoke all on function public.kasudlo_list_health_tip_patients() from public;
grant execute on function public.kasudlo_list_health_tip_patients()
  to authenticated, service_role;

drop policy if exists health_tips_select_authenticated on public.health_tips;
create policy health_tips_select_authenticated
on public.health_tips
for select
to authenticated
using (
  (
    target_patient_id is null
    and coalesce(array_length(target_patient_ids, 1), 0) = 0
  )
  or target_patient_id = (select auth.uid())
  or (select auth.uid()) = any(target_patient_ids)
  or (select public.is_kasudlo_health_tip_manager(auth.uid()))
);
