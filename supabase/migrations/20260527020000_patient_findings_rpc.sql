-- Create a function to allow patients to fetch their own household assessments.
-- Matches by respondent_name against the authenticated user's full_name.
create or replace function public.kasudlo_get_patient_findings()
returns setof public.household_assessments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_full_name text;
begin
  if v_user_id is null then 
    return; 
  end if;

  -- Get the full name of the logged-in patient
  select full_name into v_full_name 
  from public.user_profiles 
  where id = v_user_id;

  -- Return matching assessments, not deleted, ordered by creation date
  return query
  select * from public.household_assessments
  where respondent_name ilike v_full_name
  and is_deleted = false
  order by created_at desc;
end;
$$;

-- Ensure authenticated users can call this function
grant execute on function public.kasudlo_get_patient_findings() to authenticated;
