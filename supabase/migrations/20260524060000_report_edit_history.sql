alter table public.household_assessments
  add column if not exists edit_history jsonb not null default '[]'::jsonb;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'household_assessments_edit_history_array_check'
      and conrelid = 'public.household_assessments'::regclass
  ) then
    alter table public.household_assessments
      add constraint household_assessments_edit_history_array_check
      check (jsonb_typeof(edit_history) = 'array');
  end if;
end $$;

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
  v_edit_history jsonb;
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

  v_edit_history := case
    when jsonb_typeof(payload -> 'edit_history') = 'array'
      then payload -> 'edit_history'
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
    edit_history,
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
    v_edit_history,
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
      edit_history = case
        when jsonb_typeof(payload -> 'edit_history') = 'array'
          then excluded.edit_history
        else public.household_assessments.edit_history
      end,
      payload = excluded.payload,
      submitted_at = timezone('utc', now())
  returning id into v_assessment_id;

  return v_assessment_id;
end;
$$;

revoke all on function public.kasudlo_submit_household_assessment(jsonb, text)
  from public;
grant execute on function public.kasudlo_submit_household_assessment(jsonb, text)
  to authenticated;
