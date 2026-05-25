create or replace function pg_temp.kasudlo_normalize_family_member_keys(
  p_value jsonb
)
returns jsonb
language sql
stable
as $$
  select coalesce(
    jsonb_agg(
      case
        when jsonb_typeof(member) = 'object' then
          (
            case
              when member ? 'relationship' and not (member ? 'relationship_to_head')
                then jsonb_set(
                  case
                    when member ? 'name' and not (member ? 'name_of_family_member')
                      then jsonb_set(member, '{name_of_family_member}', member -> 'name', true)
                    else member
                  end,
                  '{relationship_to_head}',
                  member -> 'relationship',
                  true
                )
              else
                case
                  when member ? 'name' and not (member ? 'name_of_family_member')
                    then jsonb_set(member, '{name_of_family_member}', member -> 'name', true)
                  else member
                end
            end
          ) - 'name' - 'relationship'
        else member
      end
      order by ord
    ),
    '[]'::jsonb
  )
  from jsonb_array_elements(
    case
      when jsonb_typeof(p_value) = 'array' then p_value
      else '[]'::jsonb
    end
  ) with ordinality as items(member, ord);
$$;

create or replace function pg_temp.kasudlo_normalize_assessment_payload_keys(
  p_payload jsonb
)
returns jsonb
language plpgsql
stable
as $$
declare
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
begin
  if jsonb_typeof(v_payload) <> 'object' then
    return '{}'::jsonb;
  end if;

  if jsonb_typeof(v_payload -> 'family_members') = 'array' then
    v_payload := jsonb_set(
      v_payload,
      '{family_members}',
      pg_temp.kasudlo_normalize_family_member_keys(v_payload -> 'family_members'),
      true
    );
  end if;

  if jsonb_typeof(v_payload #> '{survey_data,family_members}') = 'array' then
    v_payload := jsonb_set(
      v_payload,
      '{survey_data,family_members}',
      pg_temp.kasudlo_normalize_family_member_keys(
        v_payload #> '{survey_data,family_members}'
      ),
      true
    );
  end if;

  return v_payload;
end;
$$;

with normalized as (
  select
    id,
    pg_temp.kasudlo_normalize_family_member_keys(family_members) as family_members,
    pg_temp.kasudlo_normalize_assessment_payload_keys(payload) as payload
  from public.household_assessments
)
update public.household_assessments as assessment
set
  family_members = normalized.family_members,
  payload = normalized.payload
from normalized
where assessment.id = normalized.id
  and (
    assessment.family_members is distinct from normalized.family_members
    or assessment.payload is distinct from normalized.payload
  );
