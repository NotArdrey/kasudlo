create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid null references auth.users (id) on delete set null,
  actor_email text not null default '',
  actor_role text not null default 'worker',
  action text not null check (length(btrim(action)) > 0),
  entity_type text not null default 'system',
  entity_id text null,
  summary text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists audit_logs_created_at_idx
  on public.audit_logs (created_at desc);

create index if not exists audit_logs_actor_idx
  on public.audit_logs (actor_user_id, created_at desc);

create index if not exists audit_logs_action_idx
  on public.audit_logs (action, created_at desc);

alter table public.audit_logs enable row level security;

create or replace function public.prevent_audit_log_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  raise exception 'Audit logs are append-only.';
end;
$$;

drop trigger if exists audit_logs_prevent_update on public.audit_logs;
create trigger audit_logs_prevent_update
before update on public.audit_logs
for each row execute function public.prevent_audit_log_mutation();

drop trigger if exists audit_logs_prevent_delete on public.audit_logs;
create trigger audit_logs_prevent_delete
before delete on public.audit_logs
for each row execute function public.prevent_audit_log_mutation();

drop policy if exists audit_logs_select_admin on public.audit_logs;
create policy audit_logs_select_admin
on public.audit_logs
for select
to authenticated
using (public.is_kasudlo_admin(auth.uid()));

revoke insert, update, delete on public.audit_logs from anon, authenticated;
grant select on public.audit_logs to authenticated;

create or replace function public.kasudlo_log_audit_event(
  p_action text,
  p_entity_type text default 'system',
  p_entity_id text default null,
  p_summary text default '',
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_actor_email text := '';
  v_actor_role text := 'worker';
  v_event_id uuid;
begin
  if v_user_id is null then
    raise exception 'Sign in before writing an audit event.';
  end if;

  select
    coalesce(nullif(email, ''), v_actor_email),
    coalesce(nullif(role, ''), v_actor_role)
  into v_actor_email, v_actor_role
  from public.profiles
  where id = v_user_id;

  if v_actor_email = '' then
    select coalesce(email, '') into v_actor_email
    from auth.users
    where id = v_user_id;
  end if;

  insert into public.audit_logs (
    actor_user_id,
    actor_email,
    actor_role,
    action,
    entity_type,
    entity_id,
    summary,
    metadata
  )
  values (
    v_user_id,
    coalesce(v_actor_email, ''),
    coalesce(v_actor_role, 'worker'),
    lower(btrim(p_action)),
    coalesce(nullif(lower(btrim(p_entity_type)), ''), 'system'),
    nullif(btrim(coalesce(p_entity_id, '')), ''),
    left(coalesce(p_summary, ''), 240),
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_event_id;

  return v_event_id;
end;
$$;

create or replace function public.kasudlo_admin_list_audit_logs(
  p_limit integer default 100,
  p_search text default ''
)
returns table (
  id uuid,
  actor_user_id uuid,
  actor_email text,
  actor_role text,
  action text,
  entity_type text,
  entity_id text,
  summary text,
  metadata jsonb,
  created_at timestamptz
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_search text := lower(btrim(coalesce(p_search, '')));
  v_limit integer := least(greatest(coalesce(p_limit, 100), 1), 200);
begin
  if not public.is_kasudlo_admin(auth.uid()) then
    raise exception 'Only admins can view audit logs.';
  end if;

  return query
  select
    logs.id,
    logs.actor_user_id,
    logs.actor_email,
    logs.actor_role,
    logs.action,
    logs.entity_type,
    logs.entity_id,
    logs.summary,
    logs.metadata,
    logs.created_at
  from public.audit_logs as logs
  where v_search = ''
     or lower(logs.actor_email) like '%' || v_search || '%'
     or lower(logs.actor_role) like '%' || v_search || '%'
     or lower(logs.action) like '%' || v_search || '%'
     or lower(logs.entity_type) like '%' || v_search || '%'
     or lower(coalesce(logs.entity_id, '')) like '%' || v_search || '%'
     or lower(logs.summary) like '%' || v_search || '%'
  order by logs.created_at desc
  limit v_limit;
end;
$$;

revoke all on function public.kasudlo_log_audit_event(text, text, text, text, jsonb)
  from public;
revoke all on function public.kasudlo_admin_list_audit_logs(integer, text)
  from public;

grant execute on function public.kasudlo_log_audit_event(text, text, text, text, jsonb)
  to authenticated;
grant execute on function public.kasudlo_admin_list_audit_logs(integer, text)
  to authenticated;
