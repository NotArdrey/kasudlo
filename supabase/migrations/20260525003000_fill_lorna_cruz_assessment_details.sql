do $$
declare
  v_family_members jsonb := $json$
[
  {
    "member_no": 1,
    "name_of_family_member": "Lorna Cruz",
    "relationship_to_head": "Head",
    "gender": "Female",
    "age": 65,
    "birthdate_month": 8,
    "birthdate_day": 14,
    "birthdate_year": 1960,
    "marital_status": "Widow",
    "religion": "Roman Catholic",
    "highest_educational_completed": "High School Graduate",
    "occupation_status": "Unemployed",
    "place_of_work_location": "Within the community",
    "place_of_work_category": "In-House",
    "place_of_origin": "Central Luzon",
    "length_of_residence": "32 years"
  },
  {
    "member_no": 2,
    "name_of_family_member": "Rica Cruz",
    "relationship_to_head": "Grandchild",
    "gender": "Female",
    "age": 9,
    "birthdate_month": 2,
    "birthdate_day": 3,
    "birthdate_year": 2017,
    "marital_status": "Child",
    "religion": "Roman Catholic",
    "highest_educational_completed": "Elementary Level",
    "occupation_status": "Minor, below 18 years old",
    "place_of_work_location": "Within the community",
    "place_of_work_category": "In-House",
    "place_of_origin": "Central Luzon",
    "length_of_residence": "9 years"
  }
]
$json$::jsonb;
  v_payload jsonb := $json$
{
  "control_no": "CTRL-003",
  "number_of_family": 2,
  "address": "Sitio Maligaya, Barangay Mabini",
  "first_visit_date": "2026-05-22",
  "second_visit_date": "2026-05-23",
  "third_visit_date": "2026-05-24",
  "informant": "Lorna Cruz",
  "surveyed_by": "Nurse Li",
  "time_started": "09:15",
  "time_finished": "10:45",
  "status_of_last_visit": "Completed",
  "family_members": [
    {
      "member_no": 1,
      "name_of_family_member": "Lorna Cruz",
      "relationship_to_head": "Head",
      "gender": "Female",
      "age": 65,
      "birthdate_month": 8,
      "birthdate_day": 14,
      "birthdate_year": 1960,
      "marital_status": "Widow",
      "religion": "Roman Catholic",
      "highest_educational_completed": "High School Graduate",
      "occupation_status": "Unemployed",
      "place_of_work_location": "Within the community",
      "place_of_work_category": "In-House",
      "place_of_origin": "Central Luzon",
      "length_of_residence": "32 years"
    },
    {
      "member_no": 2,
      "name_of_family_member": "Rica Cruz",
      "relationship_to_head": "Grandchild",
      "gender": "Female",
      "age": 9,
      "birthdate_month": 2,
      "birthdate_day": 3,
      "birthdate_year": 2017,
      "marital_status": "Child",
      "religion": "Roman Catholic",
      "highest_educational_completed": "Elementary Level",
      "occupation_status": "Minor, below 18 years old",
      "place_of_work_location": "Within the community",
      "place_of_work_category": "In-House",
      "place_of_origin": "Central Luzon",
      "length_of_residence": "9 years"
    }
  ],
  "family_composition_type": ["Extended", "Living with Grandparent(s)"],
  "family_locus_of_power": "Matricentric",
  "family_place_of_residence": "Neolocal",
  "family_descent": "Bilateral",
  "dialect_frequently_used": "Tagalog",
  "services_in_community": ["Health Services", "Garbage collection"],
  "institutional_facilities": ["Brgy. Hall", "Health Station", "Church"],
  "organizations": ["Senior Citizen"],
  "traditions_customs": ["Bayanihan", "Fiestas", "Respect for elderly"],
  "recreational_facilities": ["Plaza"],
  "mode_of_transportation": ["Tricycle"],
  "mode_of_communication": ["Cell phone"],
  "income_earner_count": 1,
  "income_earners": [
    {
      "earner_no": 1,
      "family_position": "Grandchild support",
      "income_php": 6000
    }
  ],
  "monthly_family_income_combined": "5,001-10,000",
  "financial_sources": ["Pension", "Help from relative/friends"],
  "monthly_family_expenditures": "5,001-10,000",
  "priority_food_rank": 1,
  "priority_clothing_rank": 5,
  "priority_education_rank": 3,
  "priority_utilities_rank": 4,
  "priority_health_rank": 2,
  "priority_recreation_rank": 7,
  "priority_savings_rank": 6,
  "family_income_adequacy": "Not Adequate",
  "cultural_orientation_illness": [
    "Illness is caused by physiologic factor, e.g. infection",
    "Illness is caused by change in weather"
  ],
  "cultural_belief_health_restoration": [
    "Health can be restored by God/other spiritual faith",
    "Health can be restored by health personnel, e.g. doctors, nurses"
  ],
  "cultural_perception_health_practices": "Sometimes practices local cultural practices about health matters",
  "community_involvement": "Actively joins fiesta, religious procession, local cultural practices",
  "home_ownership": "Owned",
  "home_construction_materials": "Light",
  "sleeping_rooms_count": "1",
  "home_space_adequacy": "Inadequate",
  "lighting_facility": "Electricity",
  "lighting_adequacy": "Adequate",
  "ventilation_adequacy": "Inadequate",
  "general_sanitary_condition": "Dirty",
  "water_supply_ownership": "Public",
  "water_source_cooking": "Deep well",
  "water_source_drinking": "Commercial",
  "water_source_bathing_cr_flushing": "Deep well",
  "water_potability_key_informant": "No",
  "water_storage": "Large covered container without faucet",
  "water_source_distance_from_house": "30 meters",
  "food_storage_cover_status": "Covered",
  "food_storage_type": ["Cabinet", "Basket"],
  "cooking_facility": ["Gas stove", "Firewood/charcoal"],
  "cooking_area_sanitary_condition": "Generally clean",
  "garbage_storage": "Container",
  "waste_segregation": "Not Practiced",
  "waste_disposal_method_if_not_practiced": ["Open burning", "Collected"],
  "reason_for_not_practicing_waste_segregation": [
    "Not aware of effects",
    "Long-time practice of family"
  ],
  "toilet_ownership": "None",
  "toilet_type": "None",
  "toilet_location_from_water_source": "Not applicable",
  "toilet_sanitary_condition": "Dirty",
  "drainage_system": "Open drainage",
  "drainage_condition": "Stagnant",
  "has_rabies_carrier_animals": "Yes",
  "rabies_carrier_animals": [
    {
      "animal_kind": "Dog",
      "animal_number": 1,
      "kept_inside_yard": false,
      "kept_free_outside": true,
      "with_regular_vaccination": false,
      "without_vaccination": true
    }
  ],
  "vector_control_measures": ["Cleaning the yard"],
  "has_breeding_sites_observed": "Yes",
  "housing_congestion_observed": "No",
  "has_industrial_establishment_or_factory_observed": "No",
  "uses_safety_devices_when_necessary": "Practice",
  "has_cigarette_smoker_in_family": "No",
  "uses_prohibited_or_dangerous_drugs": "No",
  "alcohol_drinkers": [
    {
      "name": "Lorna Cruz",
      "age": 65,
      "age_started_drinking_alcohol": 0,
      "frequency": "Never",
      "reason": "Does not drink"
    }
  ],
  "anthropometric_data_under_5": [],
  "food_recall_24_hour": [
    {
      "date": "2026-05-23",
      "time_of_day": "Breakfast",
      "food_taken": "Rice porridge and coffee"
    },
    {
      "date": "2026-05-23",
      "time_of_day": "Lunch",
      "food_taken": "Rice, dried fish, and boiled vegetables"
    },
    {
      "date": "2026-05-23",
      "time_of_day": "Dinner",
      "food_taken": "Rice and vegetable soup"
    }
  ],
  "first_food_choice": "Vegetable",
  "first_food_choice_servings": "1",
  "second_food_choice": "Fish",
  "second_food_choice_servings": "1",
  "reason_for_food_choices": ["Affordable", "Health condition"],
  "reason_for_not_choosing_other_food_options": ["Not affordable"],
  "food_intake_frequency": "Everyday",
  "food_prepared_for_mealtime": "Prepared at home",
  "food_preparation_frequency": "Everyday",
  "canned_preserved_food_frequency": "Sometimes",
  "grilled_food_frequency": "Never",
  "carbonated_beverage_frequency": "Never",
  "personnel_consulted_during_illness": ["Doctor", "Midwife", "Elderly"],
  "measures_taken_during_illness": ["Consult a Rural Health Team", "Self-Medication"],
  "medication_treatment_during_illness": ["Prescribed by Doctor", "Self-Medication/OTC drugs"],
  "medical_checkup_frequency": "Twice a year",
  "dental_checkup_frequency": "More than a year",
  "barangay_health_center_services_available": "BP monitoring, senior citizen consultation, immunization, and nutrition counseling",
  "immunization_records": [
    {
      "name": "Rica Cruz",
      "age_in_months": 108,
      "gender": "Female",
      "bcg": "2017-03-03",
      "dpt_1": "2017-04-03",
      "dpt_2": "2017-05-03",
      "dpt_3": "2017-06-03",
      "hepa_b_1": "2017-03-05",
      "hepa_b_2": "2017-04-05",
      "hepa_b_3": "2017-05-05",
      "opv_1": "2017-04-07",
      "opv_2": "2017-05-07",
      "opv_3": "2017-06-07",
      "measles": "2018-02-03",
      "complete_according_to_age": true,
      "incomplete_according_to_age": false,
      "fully_immunized_child": true
    }
  ],
  "antenatal_registrations": [],
  "family_planning_eligible": false,
  "family_planning_status": "Non-Acceptor",
  "family_planning_non_acceptor_reasons": ["Bad for health of family"],
  "permanent_method_female_sterilization_btl": false,
  "permanent_method_male_sterilization_vasectomy": false,
  "supply_method_pills": false,
  "supply_method_iud": false,
  "supply_method_injectable": false,
  "supply_method_condoms": false,
  "supply_method_implant": false,
  "fertility_method_cervical_mucus_billings": false,
  "fertility_method_basal_body_temperature": false,
  "fertility_method_sympto_thermal": false,
  "fertility_method_standard_days": false,
  "fertility_method_lactational_amenorrhea": false,
  "morbidity_records": [
    {
      "name": "Lorna Cruz",
      "age": 65,
      "gender": "Female",
      "cause": "Hypertension",
      "intervention_with": true,
      "intervention_without": false,
      "admitted": false,
      "not_admitted": true
    }
  ],
  "mortality_records": [],
  "non_communicable_disease_records": [
    {
      "name": "Lorna Cruz",
      "age": 65,
      "gender": "Female",
      "ncd": "Hypertension"
    },
    {
      "name": "Lorna Cruz",
      "age": 65,
      "gender": "Female",
      "ncd": "Arthritis"
    }
  ],
  "communicable_disease_records": [],
  "blood_pressure_records": [
    {
      "name": "Lorna Cruz",
      "age": 65,
      "gender": "Female",
      "bp": "150/90"
    }
  ],
  "awareness_of_bhc_rhu_health_services": "Aware",
  "health_manpower_categories_available": "BHW, midwife, nurse",
  "health_manpower_geographical_distribution": "Barangay health station is one tricycle ride away",
  "rhu_team_per_population_summary": "1 RHU team serves nearby sitios",
  "physician_count_per_population": "1:5000",
  "nurse_count_per_population": "1:2500",
  "midwife_count_per_population": "1:1000",
  "other_rhu_team_count_per_population": "2 BHWs per purok",
  "existing_manpower_development_policies": "Quarterly BHW training and senior citizen monitoring",
  "rhu_physicians_schedule": "Monday 9 AM",
  "rhu_nurse_schedule": "Tuesday 9 AM",
  "bhc_midwife_schedule": "Wednesday 9 AM",
  "health_budget_expenditures_availability": "Available",
  "health_budget_amount_per_year_php": 80000,
  "supplies_equipment_availability": "Limited Supplies",
  "recognized_formal_elected_leaders": ["Captain", "Kagawad"],
  "recognized_non_formal_leaders": ["BHW", "Elderly"],
  "social_conflict_causes": ["Gossip", "Alcohol drinking"],
  "conflict_resolution_approaches": ["Brgy. hearing", "Settlement among involved parties"],
  "general_lifestyle_area_concerns_suggestions": "Needs sanitary toilet assistance, nutrition support, drainage clearing, and regular senior BP checks.",
  "health_problems": ["Hypertension", "Arthritis"],
  "vaccination_status": "Complete",
  "water_sanitation": "No sanitary toilet",
  "nutritional_status": "Underweight",
  "community_concerns": ["Malnutrition", "Poor sanitation", "Limited clinic access"],
  "notes": "Prioritize nutrition screening, home sanitation follow-up, and BP monitoring.",
  "account_create_requested": false,
  "account_email": ""
}
$json$::jsonb;
  v_updated_count integer := 0;
begin
  if to_regclass('public.household_assessments') is null then
    raise notice 'Skipping Lorna Cruz data fill because public.household_assessments does not exist.';
    return;
  end if;

  update public.household_assessments
  set
    respondent_name = 'Lorna Cruz',
    respondent_age = 65,
    address = 'Sitio Maligaya, Barangay Mabini',
    family_members_count = 2,
    family_members = v_family_members,
    health_problems = array['Hypertension', 'Arthritis']::text[],
    vaccination_status = 'Complete',
    water_sanitation = 'No sanitary toilet',
    nutritional_status = 'Underweight',
    community_concerns = array[
      'Malnutrition',
      'Poor sanitation',
      'Limited clinic access'
    ]::text[],
    consent_given = true,
    notes = 'Prioritize nutrition screening, home sanitation follow-up, and BP monitoring.',
    payload = v_payload,
    updated_at = timezone('utc', now())
  where client_submission_id = 'demo-household-003'
     or lower(respondent_name) = lower('Lorna Cruz');

  get diagnostics v_updated_count = row_count;

  raise notice 'Filled Lorna Cruz details for % Supabase household assessment row(s).',
    v_updated_count;
end $$;
