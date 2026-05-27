-- Add soft-delete columns to household_assessments
alter table public.household_assessments
  add column if not exists is_deleted boolean not null default false,
  add column if not exists deleted_at timestamptz null,
  add column if not exists deleted_by text null;

create index if not exists household_assessments_is_deleted_idx
  on public.household_assessments (is_deleted);

-- Update the submit RPC to handle soft-delete fields from the payload
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
  v_is_deleted boolean;
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

  v_is_deleted := coalesce((payload ->> 'is_deleted')::boolean, false);

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
    submitted_at,
    is_deleted,
    deleted_at,
    deleted_by
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
    timezone('utc', now()),
    v_is_deleted,
    case when v_is_deleted then nullif(trim(payload ->> 'deleted_at'), '')::timestamptz else null end,
    case when v_is_deleted then nullif(trim(payload ->> 'deleted_by'), '') else null end
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
      submitted_at = timezone('utc', now()),
      is_deleted = excluded.is_deleted,
      deleted_at = excluded.deleted_at,
      deleted_by = excluded.deleted_by
  returning id into v_assessment_id;

  return v_assessment_id;
end;
$$;
