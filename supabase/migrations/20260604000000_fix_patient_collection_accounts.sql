-- Allow patient accounts created during collection to find their submitted
-- household assessment after login.
create or replace function public.kasudlo_get_patient_findings()
returns setof public.household_assessments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_full_name text := '';
  v_email text := '';
begin
  if v_user_id is null then
    return;
  end if;

  select
    coalesce(full_name, ''),
    coalesce(email, '')
  into v_full_name, v_email
  from public.profiles
  where id = v_user_id;

  return query
  select assessment.*
  from public.household_assessments as assessment
  where coalesce(assessment.is_deleted, false) = false
    and (
      (
        btrim(v_full_name) <> ''
        and lower(btrim(assessment.respondent_name)) =
            lower(btrim(v_full_name))
      )
      or (
        btrim(v_email) <> ''
        and lower(btrim(coalesce(assessment.payload ->> 'account_email', ''))) =
            lower(btrim(v_email))
      )
      or (
        btrim(v_email) <> ''
        and lower(
          btrim(coalesce(assessment.payload #>> '{survey_data,account_email}', ''))
        ) = lower(btrim(v_email))
      )
    )
  order by assessment.created_at desc;
end;
$$;

revoke all on function public.kasudlo_get_patient_findings() from anon;
grant execute on function public.kasudlo_get_patient_findings() to authenticated;
