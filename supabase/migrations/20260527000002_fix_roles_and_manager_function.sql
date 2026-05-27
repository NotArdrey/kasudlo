-- Update health tip manager check
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
      and role in ('nurse', 'admin')
  );
$$;

-- Update audit logs default and function
alter table public.audit_logs alter column actor_role set default 'nurse';

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
  v_actor_role text := 'nurse';
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
    coalesce(v_actor_role, 'nurse'),
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
