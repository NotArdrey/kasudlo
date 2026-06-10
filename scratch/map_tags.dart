import 'dart:io';

void main() {
  final file = File('scratch/tags_utf8.txt');
  if (!file.existsSync()) return;

  final tags = file.readAsLinesSync().map((t) => t.replaceAll('{{', '').replaceAll('}}', '').trim()).toSet().toList();

  final mappings = <String, String>{};

  for (final tag in tags) {
    if (tag.isEmpty) continue;

    // Services
    if (tag == 'community_services_religious') mappings[tag] = "value('services_in_community').contains('Religious services')";
    if (tag == 'community_services_livelihood') mappings[tag] = "value('services_in_community').contains('Livelihood Services')";
    if (tag == 'community_services_health') mappings[tag] = "value('services_in_community').contains('Health Services')";
    if (tag == 'community_services_garbage') mappings[tag] = "value('services_in_community').contains('Garbage collection')";
    if (tag == 'community_services_peace') mappings[tag] = "value('services_in_community').contains('Peace and Order')";

    // Institutions
    if (tag == 'institution_brgy_hall') mappings[tag] = "value('institutional_facilities').contains('Brgy. Hall')";
    if (tag == 'institution_health_station') mappings[tag] = "value('institutional_facilities').contains('Health Station')";
    if (tag == 'institution_church') mappings[tag] = "value('institutional_facilities').contains('Church')";
    if (tag == 'institution_school') mappings[tag] = "value('institutional_facilities').contains('School')";

    // Organizations
    if (tag == 'organization_senior_citizen') mappings[tag] = "value('organizations').contains('Senior Citizen')";
    if (tag == 'organization_youth') mappings[tag] = "value('organizations').contains('Youth')";
    if (tag == 'organization_others_checked' || tag == 'org_others_checked') mappings[tag] = "value('organizations').contains('Others')";
    if (tag == 'org_others' || tag == 'organization_others') mappings[tag] = "value('organizations_other')";

    // Traditions
    if (tag == 'tradition_bayanihan') mappings[tag] = "value('traditions_customs').contains('Bayanihan')";
    if (tag == 'tradition_palabra_de_honor') mappings[tag] = "value('traditions_customs').contains('Palabra de Honor')";
    if (tag == 'tradition_pakikisama') mappings[tag] = "value('traditions_customs').contains('Pakikisama')";
    if (tag == 'tradition_ningas_kugon') mappings[tag] = "value('traditions_customs').contains('Ningas Kugon')";
    if (tag == 'tradition_fiestas') mappings[tag] = "value('traditions_customs').contains('Fiestas')";
    if (tag == 'tradition_close_family_ties') mappings[tag] = "value('traditions_customs').contains('Close family ties')";
    if (tag == 'tradition_respect_for_elderly') mappings[tag] = "value('traditions_customs').contains('Respect for elderly')";
    if (tag == 'tradition_others_checked') mappings[tag] = "value('traditions_customs').contains('Others')";
    if (tag == 'tradition_custom_other' || tag == 'tradition_others') mappings[tag] = "value('traditions_customs_other')";

    // Recreational
    if (tag == 'recreation_basketball_volleyball_court') mappings[tag] = "value('recreational_facilities').contains('Volleyball/Basketball court')";
    if (tag == 'recreation_playground') mappings[tag] = "value('recreational_facilities').contains('Playground')";
    if (tag == 'recreation_plaza') mappings[tag] = "value('recreational_facilities').contains('Plaza')";
    if (tag == 'recreation_others_checked') mappings[tag] = "value('recreational_facilities').contains('Others')";
    if (tag == 'recreational_others' || tag == 'recreation_others') mappings[tag] = "value('recreational_facilities_other')";

    // Transportation
    if (tag == 'transport_tricycle') mappings[tag] = "value('mode_of_transportation').contains('Tricycle')";
    if (tag == 'transport_jeep') mappings[tag] = "value('mode_of_transportation').contains('Jeep')";
    if (tag == 'transport_puj_puv') mappings[tag] = "value('mode_of_transportation').contains('PUJ/PUV')";
    if (tag == 'transport_bicycle') mappings[tag] = "value('mode_of_transportation').contains('Bicycle')";
    if (tag == 'transport_private_vehicle') mappings[tag] = "value('mode_of_transportation').contains('Private vehicle')";

    // Communication
    if (tag == 'communication_postal_system') mappings[tag] = "value('mode_of_communication').contains('Postal system')";
    if (tag == 'communication_internet') mappings[tag] = "value('mode_of_communication').contains('Internet')";
    if (tag == 'communication_telephone') mappings[tag] = "value('mode_of_communication').contains('Telephone')";
    if (tag == 'communication_cell_phone') mappings[tag] = "value('mode_of_communication').contains('Cell phone')";
    if (tag == 'communication_two_way_radio') mappings[tag] = "value('mode_of_communication').contains('Two-way radio')";
    if (tag == 'communication_others_checked') mappings[tag] = "value('mode_of_communication').contains('Others')";
    if (tag == 'communication_other') mappings[tag] = "value('mode_of_communication_other')";

    // Monthly Income
    if (tag == 'income_less_5000') mappings[tag] = "value('monthly_family_income_combined') == 'Less than 5,000'";
    if (tag == 'income_5001_10000') mappings[tag] = "value('monthly_family_income_combined') == '5,001-10,000'";
    if (tag == 'income_10001_15000') mappings[tag] = "value('monthly_family_income_combined') == '10,001-15,000'";
    if (tag == 'income_15001_20000') mappings[tag] = "value('monthly_family_income_combined') == '15,001-20,000'";
    if (tag == 'income_20001_25000') mappings[tag] = "value('monthly_family_income_combined') == '20,001-25,000'";
    if (tag == 'income_25001_30000') mappings[tag] = "value('monthly_family_income_combined') == '25,001-30,000'";
    if (tag == 'income_30001_35000') mappings[tag] = "value('monthly_family_income_combined') == '30,001-35,000'";
    if (tag == 'income_35001_40000') mappings[tag] = "value('monthly_family_income_combined') == '35,001-40,000'";
    if (tag == 'income_40001_45000') mappings[tag] = "value('monthly_family_income_combined') == '40,001-45,000'";
    if (tag == 'income_45001_50000') mappings[tag] = "value('monthly_family_income_combined') == '45,001-50,000'";
    if (tag == 'income_50001_above') mappings[tag] = "value('monthly_family_income_combined') == '50,001 and above'";
    if (tag == 'income_adequate') mappings[tag] = "value('family_income_adequacy') == 'Adequate'";
    if (tag == 'income_not_adequate') mappings[tag] = "value('family_income_adequacy') == 'Not Adequate'";

    // Financial Source
    if (tag == 'financial_source_employment') mappings[tag] = "value('financial_sources').contains('Employment')";
    if (tag == 'financial_source_business') mappings[tag] = "value('financial_sources').contains('Business')";
    if (tag == 'financial_source_pension') mappings[tag] = "value('financial_sources').contains('Pension')";
    if (tag == 'financial_source_help') mappings[tag] = "value('financial_sources').contains('Help from relative/friends')";
    if (tag == 'financial_source_others_checked') mappings[tag] = "value('financial_sources').contains('Others')";
    if (tag == 'financial_source_other' || tag == 'financial_source_others') mappings[tag] = "value('financial_sources_other')";

    // Expenditures
    if (tag == 'expenditure_less_5000') mappings[tag] = "value('monthly_family_expenditures') == 'Less than 5,000'";
    if (tag == 'expenditure_5001_10000') mappings[tag] = "value('monthly_family_expenditures') == '5,001-10,000'";
    if (tag == 'expenditure_10001_15000') mappings[tag] = "value('monthly_family_expenditures') == '10,001-15,000'";
    if (tag == 'expenditure_15001_20000') mappings[tag] = "value('monthly_family_expenditures') == '15,001-20,000'";
    if (tag == 'expenditure_20001_25000') mappings[tag] = "value('monthly_family_expenditures') == '20,001-25,000'";
    if (tag == 'expenditure_25001_30000') mappings[tag] = "value('monthly_family_expenditures') == '25,001-30,000'";
    if (tag == 'expenditure_30001_35000') mappings[tag] = "value('monthly_family_expenditures') == '30,001-35,000'";
    if (tag == 'expenditure_35001_40000') mappings[tag] = "value('monthly_family_expenditures') == '35,001-40,000'";
    if (tag == 'expenditure_40001_45000') mappings[tag] = "value('monthly_family_expenditures') == '40,001-45,000'";
    if (tag == 'expenditure_45001_50000') mappings[tag] = "value('monthly_family_expenditures') == '45,001-50,000'";
    if (tag == 'expenditure_50001_above') mappings[tag] = "value('monthly_family_expenditures') == '50,001 and above'";

    // Cultural Beliefs
    if (tag == 'illness_cause_physiologic') mappings[tag] = "value('cultural_orientation_illness').contains('Illness is caused by physiologic factor, e.g. infection')";
    if (tag == 'illness_cause_supernatural') mappings[tag] = "value('cultural_orientation_illness').contains('Illness is caused by supernatural phenomenon, e.g. kulam, balis')";
    if (tag == 'illness_cause_punishment_from_god') mappings[tag] = "value('cultural_orientation_illness').contains('Illness is a punishment from God')";
    if (tag == 'illness_cause_other_person') mappings[tag] = "value('cultural_orientation_illness').contains('Illness is caused by other person')";
    if (tag == 'illness_cause_weather_change') mappings[tag] = "value('cultural_orientation_illness').contains('Illness is caused by change in weather')";
    if (tag == 'illness_cause_others_checked') mappings[tag] = "value('cultural_orientation_illness').contains('Others')";
    if (tag == 'illness_cause_others' || tag == 'illness_cause_other') mappings[tag] = "value('cultural_orientation_illness_other')";
    
    if (tag == 'health_restored_by_god_faith') mappings[tag] = "value('cultural_belief_health_restoration').contains('Health can be restored by God/other spiritual faith')";
    if (tag == 'health_restored_by_faith_healers') mappings[tag] = "value('cultural_belief_health_restoration').contains('Health can be restored by faith healers')";
    if (tag == 'health_restored_by_supernatural_power') mappings[tag] = "value('cultural_belief_health_restoration').contains('Health can be restored by supernatural power, e.g. tawas, hilot, hula')";
    if (tag == 'health_restored_by_health_personnel') mappings[tag] = "value('cultural_belief_health_restoration').contains('Health can be restored by health personnel, e.g. doctors, nurses')";
    
    if (tag == 'cultural_practice_always') mappings[tag] = "value('cultural_perception_health_practices') == 'Always practices local cultural practices about health matters'";
    if (tag == 'cultural_practice_sometimes') mappings[tag] = "value('cultural_perception_health_practices') == 'Sometimes practices local cultural practices about health matters'";
    if (tag == 'cultural_practice_never') mappings[tag] = "value('cultural_perception_health_practices') == 'Does not practice any local cultural practices about health matters'";

    if (tag == 'community_involve_yes') mappings[tag] = "value('community_involvement') == 'Actively joins fiesta, religious procession, local cultural practices'";
    if (tag == 'community_involve_no') mappings[tag] = "value('community_involvement') == 'Does not actively join'";

    // Home / Shelter
    if (tag == 'home_owned') mappings[tag] = "value('home_ownership') == 'Owned'";
    if (tag == 'home_rented') mappings[tag] = "value('home_ownership') == 'Rented'";
    if (tag == 'home_rent_free') mappings[tag] = "value('home_ownership') == 'Rent-free'";
    if (tag == 'home_lease_to_own') mappings[tag] = "value('home_ownership') == 'Lease/Least to own'";
    if (tag == 'home_squatting_informal_settlers') mappings[tag] = "value('home_ownership') == 'Squatting/informal settlers'";
    if (tag == 'home_professional_squatters') mappings[tag] = "value('home_ownership') == 'Professional squatters'";

    if (tag == 'home_light_materials') mappings[tag] = "value('home_construction_materials') == 'Light'";
    if (tag == 'home_mixed_materials') mappings[tag] = "value('home_construction_materials') == 'Mixed'";
    if (tag == 'home_strong_concrete_materials') mappings[tag] = "value('home_construction_materials') == 'Strong/Concrete'";

    if (tag == 'sleeping_rooms_1') mappings[tag] = "value('sleeping_rooms_count') == '1'";
    if (tag == 'sleeping_rooms_2') mappings[tag] = "value('sleeping_rooms_count') == '2'";
    if (tag == 'sleeping_rooms_3') mappings[tag] = "value('sleeping_rooms_count') == '3'";
    if (tag == 'sleeping_rooms_4') mappings[tag] = "value('sleeping_rooms_count') == '4'";
    if (tag == 'sleeping_rooms_5') mappings[tag] = "value('sleeping_rooms_count') == '5'";
    if (tag == 'sleeping_rooms_none') mappings[tag] = "value('sleeping_rooms_count') == 'None/no partition'";

    if (tag == 'space_adequate') mappings[tag] = "value('home_space_adequacy') == 'Adequate'";
    if (tag == 'space_inadequate') mappings[tag] = "value('home_space_adequacy') == 'Inadequate'";

    if (tag == 'lighting_electricity') mappings[tag] = "value('lighting_facility') == 'Electricity'";
    if (tag == 'lighting_kerosene') mappings[tag] = "value('lighting_facility') == 'Kerosene'";
    if (tag == 'lighting_others_checked') mappings[tag] = "value('lighting_facility') == 'Others'";
    if (tag == 'lighting_others') mappings[tag] = "value('lighting_facility_other')";

    if (tag == 'lighting_adequate') mappings[tag] = "value('lighting_adequacy') == 'Adequate'";
    if (tag == 'lighting_inadequate') mappings[tag] = "value('lighting_adequacy') == 'Inadequate'";

    if (tag == 'ventilation_adequate') mappings[tag] = "value('ventilation_adequacy') == 'Adequate'";
    if (tag == 'ventilation_inadequate') mappings[tag] = "value('ventilation_adequacy') == 'Inadequate'";

    if (tag == 'sanitary_generally_clean') mappings[tag] = "value('general_sanitary_condition') == 'Generally clean'";
    if (tag == 'sanitary_dirty') mappings[tag] = "value('general_sanitary_condition') == 'Dirty'";

    if (tag == 'water_ownership_private') mappings[tag] = "value('water_supply_ownership') == 'Private'";
    if (tag == 'water_ownership_public') mappings[tag] = "value('water_supply_ownership') == 'Public'";

    // Water Source (Drinking)
    if (tag == 'water_drinking_deep_well') mappings[tag] = "value('water_source_drinking') == 'Deep well'";
    if (tag == 'water_drinking_local_district') mappings[tag] = "value('water_source_drinking') == 'Local Water District'";
    if (tag == 'water_drinking_commercial') mappings[tag] = "value('water_source_drinking') == 'Commercial'";
    if (tag == 'water_drinking_others_checked') mappings[tag] = "value('water_source_drinking') == 'Others'";
    if (tag == 'water_drinking_others') mappings[tag] = "value('water_source_drinking_other')";

    // Water Source (Cooking)
    if (tag == 'water_cooking_deep_well') mappings[tag] = "value('water_source_cooking') == 'Deep well'";
    if (tag == 'water_cooking_local_district') mappings[tag] = "value('water_source_cooking') == 'Local Water District'";
    if (tag == 'water_cooking_commercial') mappings[tag] = "value('water_source_cooking') == 'Commercial'";
    if (tag == 'water_cooking_others_checked') mappings[tag] = "value('water_source_cooking') == 'Others'";
    if (tag == 'water_cooking_others') mappings[tag] = "value('water_source_cooking_other')";

    // Water Source (Bathing)
    if (tag == 'water_bathing_deep_well') mappings[tag] = "value('water_source_bathing_cr_flushing') == 'Deep well'";
    if (tag == 'water_bathing_local_district') mappings[tag] = "value('water_source_bathing_cr_flushing') == 'Local Water District'";
    if (tag == 'water_bathing_commercial') mappings[tag] = "value('water_source_bathing_cr_flushing') == 'Commercial'";
    if (tag == 'water_bathing_others_checked') mappings[tag] = "value('water_source_bathing_cr_flushing') == 'Others'";
    if (tag == 'water_bathing_others') mappings[tag] = "value('water_source_bathing_cr_flushing_other')";

    if (tag == 'water_potable_yes') mappings[tag] = "value('water_potability_key_informant') == 'Yes'";
    if (tag == 'water_potable_no') mappings[tag] = "value('water_potability_key_informant') == 'No'";

    if (tag == 'water_storage_none_direct') mappings[tag] = "value('water_storage') == 'None/direct from faucet or pipe'";
    if (tag == 'water_storage_large_covered_with_faucet') mappings[tag] = "value('water_storage') == 'Large covered container with faucet'";
    if (tag == 'water_storage_large_uncovered_with_faucet') mappings[tag] = "value('water_storage') == 'Large uncovered container with faucet'";
    if (tag == 'water_storage_large_covered_without_faucet') mappings[tag] = "value('water_storage') == 'Large covered container without faucet'";
    if (tag == 'water_storage_large_uncovered_without_faucet') mappings[tag] = "value('water_storage') == 'Large uncovered container without faucet'";
    if (tag == 'water_storage_others_checked') mappings[tag] = "value('water_storage') == 'Others'";
    if (tag == 'water_storage_others') mappings[tag] = "value('water_storage_other')";
    if (tag == 'water_source_distance') mappings[tag] = "value('water_source_distance_from_house')";

    if (tag == 'food_storage_covered') mappings[tag] = "value('food_storage_cover_status') == 'Covered'";
    if (tag == 'food_storage_uncovered') mappings[tag] = "value('food_storage_cover_status') == 'Uncovered'";

    if (tag == 'storage_refrigerator') mappings[tag] = "value('food_storage_type') == 'Refrigerator'";
    if (tag == 'storage_cabinet') mappings[tag] = "value('food_storage_type') == 'Cabinet'";
    if (tag == 'storage_basket') mappings[tag] = "value('food_storage_type') == 'Basket'";
    if (tag == 'storage_table') mappings[tag] = "value('food_storage_type') == 'Table'";

    if (tag == 'cooking_electric_stove') mappings[tag] = "value('cooking_facility') == 'Electric stove'";
    if (tag == 'cooking_gas_stove') mappings[tag] = "value('cooking_facility') == 'Gas stove'";
    if (tag == 'cooking_firewood_charcoal') mappings[tag] = "value('cooking_facility') == 'Firewood/charcoal'";
    if (tag == 'cooking_others_checked') mappings[tag] = "value('cooking_facility') == 'Others'";
    if (tag == 'cooking_others') mappings[tag] = "value('cooking_facility_other')";

    if (tag == 'cooking_area_sanitary_clean') mappings[tag] = "value('cooking_area_sanitary_condition') == 'Generally clean'";
    if (tag == 'cooking_area_dirty') mappings[tag] = "value('cooking_area_sanitary_condition') == 'Dirty'";

    if (tag == 'garbage_storage_container') mappings[tag] = "value('garbage_storage') == 'Container'";
    if (tag == 'garbage_storage_none') mappings[tag] = "value('garbage_storage') == 'None'";

    if (tag == 'waste_segregation_practiced') mappings[tag] = "value('waste_segregation') == 'Practiced'";
    if (tag == 'waste_segregation_not_practiced') mappings[tag] = "value('waste_segregation') == 'Not Practiced'";

    if (tag == 'disposal_hog_feeding') mappings[tag] = "value('waste_disposal_method_if_practiced') == 'Hog-feeding' || value('waste_disposal_method_if_not_practiced') == 'Hog-feeding'";
    if (tag == 'disposal_open_dumping') mappings[tag] = "value('waste_disposal_method_if_practiced') == 'Open dumping' || value('waste_disposal_method_if_not_practiced') == 'Open dumping'";
    if (tag == 'disposal_burial_in_pit') mappings[tag] = "value('waste_disposal_method_if_practiced') == 'Burial in pit' || value('waste_disposal_method_if_not_practiced') == 'Burial in pit'";
    if (tag == 'disposal_collected') mappings[tag] = "value('waste_disposal_method_if_practiced') == 'Collected' || value('waste_disposal_method_if_not_practiced') == 'Collected'";
    if (tag == 'disposal_composting') mappings[tag] = "value('waste_disposal_method_if_practiced') == 'Composting' || value('waste_disposal_method_if_not_practiced') == 'Composting'";
    if (tag == 'disposal_open_burning') mappings[tag] = "value('waste_disposal_method_if_practiced') == 'Open burning' || value('waste_disposal_method_if_not_practiced') == 'Open burning'";

    if (tag == 'segregation_reason_environment_friendly') mappings[tag] = "value('reason_for_practicing_waste_segregation') == 'Environmentally friendly'";
    if (tag == 'segregation_reason_barangay_ordinance') mappings[tag] = "value('reason_for_practicing_waste_segregation') == 'Barangay ordinance which is strictly monitored'";
    if (tag == 'segregation_reason_business') mappings[tag] = "value('reason_for_practicing_waste_segregation') == 'Use for business'";
    if (tag == 'segregation_reason_others_checked') mappings[tag] = "value('reason_for_practicing_waste_segregation') == 'Others'";
    if (tag == 'segregation_reason_others') mappings[tag] = "value('reason_for_practicing_waste_segregation_other')";

    if (tag == 'no_segregation_not_aware') mappings[tag] = "value('reason_for_not_practicing_waste_segregation') == 'Not aware of effects'";
    if (tag == 'no_segregation_no_time') mappings[tag] = "value('reason_for_not_practicing_waste_segregation') == 'No time to do it'";
    if (tag == 'no_segregation_long_time_practice') mappings[tag] = "value('reason_for_not_practicing_waste_segregation') == 'Long-time practice of family'";
    if (tag == 'no_segregation_no_ordinance') mappings[tag] = "value('reason_for_not_practicing_waste_segregation') == 'No barangay/municipality ordinance'";

    if (tag == 'toilet_owned') mappings[tag] = "value('toilet_ownership') == 'Owned'";
    if (tag == 'toilet_shared_public') mappings[tag] = "value('toilet_ownership') == 'Shared/Public'";
    if (tag == 'toilet_none') mappings[tag] = "value('toilet_ownership') == 'None'";

    if (tag == 'toilet_ballot_system') mappings[tag] = "value('toilet_type') == 'Ballot system'";
    if (tag == 'toilet_pail_system') mappings[tag] = "value('toilet_type') == 'Pail system'";
    if (tag == 'toilet_overhung_latrine') mappings[tag] = "value('toilet_type') == 'Overhung latrine'";
    if (tag == 'toilet_water_sealed') mappings[tag] = "value('toilet_type') == 'Water-sealed'";
    if (tag == 'toilet_flush_type') mappings[tag] = "value('toilet_type') == 'Flush type'";
    if (tag == 'toilet_type_none') mappings[tag] = "value('toilet_type') == 'None'";
    if (tag == 'toilet_other_checked') mappings[tag] = "value('toilet_type') == 'Other'";
    if (tag == 'toilet_type_other') mappings[tag] = "value('toilet_type_other')";

    if (tag == 'toilet_location_less_20ft') mappings[tag] = "value('toilet_location_from_water_source') == 'Less than 20 ft.'";
    if (tag == 'toilet_location_20ft_beyond') mappings[tag] = "value('toilet_location_from_water_source') == '20 ft. beyond'";

    if (tag == 'toilet_sanitary_clean') mappings[tag] = "value('toilet_sanitary_condition') == 'Generally clean'";
    if (tag == 'toilet_sanitary_dirty') mappings[tag] = "value('toilet_sanitary_condition') == 'Dirty'";

    if (tag == 'drainage_open') mappings[tag] = "value('drainage_system') == 'Open drainage'";
    if (tag == 'drainage_blind') mappings[tag] = "value('drainage_system') == 'Blind drainage'";
    if (tag == 'drainage_none') mappings[tag] = "value('drainage_system') == 'None'";

    if (tag == 'drainage_condition_flowing') mappings[tag] = "value('drainage_condition') == 'Flowing'";
    if (tag == 'drainage_condition_stagnant') mappings[tag] = "value('drainage_condition') == 'Stagnant'";

    if (tag == 'rabies_animals_yes') mappings[tag] = "value('has_rabies_carrier_animals') == 'Yes'";
    if (tag == 'rabies_animals_no') mappings[tag] = "value('has_rabies_carrier_animals') == 'No'";

    if (tag == 'vector_control_fumigation') mappings[tag] = "value('vector_control_measures').contains('Fumigation')";
    if (tag == 'vector_control_insecticides') mappings[tag] = "value('vector_control_measures').contains('Insecticides')";
    if (tag == 'vector_control_traps') mappings[tag] = "value('vector_control_measures').contains('Setting traps')";
    if (tag == 'vector_control_cleaning_yard') mappings[tag] = "value('vector_control_measures').contains('Cleaning the yard')";
    if (tag == 'vector_control_none') mappings[tag] = "value('vector_control_measures').contains('None')";

    if (tag == 'breeding_sites_yes') mappings[tag] = "value('has_breeding_sites_observed') == 'Yes'";
    if (tag == 'breeding_sites_no') mappings[tag] = "value('has_breeding_sites_observed') == 'No'";

    if (tag == 'housing_congestion_yes') mappings[tag] = "value('housing_congestion_observed') == 'Yes'";
    if (tag == 'housing_congestion_no') mappings[tag] = "value('housing_congestion_observed') == 'No'";

    if (tag == 'industrial_establishment_yes') mappings[tag] = "value('has_industrial_establishment_or_factory_observed') == 'Yes'";
    if (tag == 'industrial_establishment_no') mappings[tag] = "value('has_industrial_establishment_or_factory_observed') == 'No'";

    if (tag == 'safety_devices_practiced') mappings[tag] = "value('uses_safety_devices_when_necessary') == 'Practice'";
    if (tag == 'safety_devices_not_practiced') mappings[tag] = "value('uses_safety_devices_when_necessary') == 'Not Practiced'";

    // Food Choices
    if (tag == 'first_choice_meat_only') mappings[tag] = "value('first_food_choice') == 'Meat only'";
    if (tag == 'first_choice_fish') mappings[tag] = "value('first_food_choice') == 'Fish'";
    if (tag == 'first_choice_vegetable') mappings[tag] = "value('first_food_choice') == 'Vegetable'";
    if (tag == 'first_choice_mixed') mappings[tag] = "value('first_food_choice') == 'Mixed'";
    if (tag == 'first_choice_others_checked') mappings[tag] = "value('first_food_choice') == 'Others'";
    if (tag == 'first_choice_others') mappings[tag] = "value('first_food_choice_other')";

    if (tag == 'first_choice_servings_1') mappings[tag] = "value('first_food_choice_servings') == '1'";
    if (tag == 'first_choice_servings_2_3') mappings[tag] = "value('first_food_choice_servings') == '2-3'";
    if (tag == 'first_choice_servings_4_5') mappings[tag] = "value('first_food_choice_servings') == '4-5 and above'";

    if (tag == 'second_choice_meat') mappings[tag] = "value('second_food_choice') == 'Meat'";
    if (tag == 'second_choice_fish') mappings[tag] = "value('second_food_choice') == 'Fish'";
    if (tag == 'second_choice_vegetable') mappings[tag] = "value('second_food_choice') == 'Vegetable'";
    if (tag == 'second_choice_mixed') mappings[tag] = "value('second_food_choice') == 'Mixed'";
    if (tag == 'second_choice_others_checked') mappings[tag] = "value('second_food_choice') == 'Others'";
    if (tag == 'second_choice_others') mappings[tag] = "value('second_food_choice_other')";

    if (tag == 'second_choice_servings_1') mappings[tag] = "value('second_food_choice_servings') == '1'";
    if (tag == 'second_choice_servings_2_3') mappings[tag] = "value('second_food_choice_servings') == '2-3'";
    if (tag == 'second_choice_servings_4_5') mappings[tag] = "value('second_food_choice_servings') == '4-5 and above'";

    if (tag == 'reason_choice_healthy') mappings[tag] = "value('reason_for_food_choices').contains('It is healthy')";
    if (tag == 'reason_choice_preference') mappings[tag] = "value('reason_for_food_choices').contains('Own preference')";
    if (tag == 'reason_choice_affordable') mappings[tag] = "value('reason_for_food_choices').contains('Affordable')";
    if (tag == 'reason_choice_personal_belief') mappings[tag] = "value('reason_for_food_choices').contains('Personal belief/practices')";
    if (tag == 'reason_choice_health_condition') mappings[tag] = "value('reason_for_food_choices').contains('Health condition')";

    if (tag == 'reason_not_choose_not_healthy') mappings[tag] = "value('reason_for_not_choosing_other_food_options').contains('Not healthy')";
    if (tag == 'reason_not_choose_preference') mappings[tag] = "value('reason_for_not_choosing_other_food_options').contains('Own preference')";
    if (tag == 'reason_not_choose_not_affordable') mappings[tag] = "value('reason_for_not_choosing_other_food_options').contains('Not affordable')";
    if (tag == 'reason_not_choose_personal_belief') mappings[tag] = "value('reason_for_not_choosing_other_food_options').contains('Personal belief/religious practices')";
    if (tag == 'reason_not_choose_health_condition') mappings[tag] = "value('reason_for_not_choosing_other_food_options').contains('Health condition')";

    if (tag == 'food_frequent_everyday') mappings[tag] = "value('food_intake_frequency') == 'Everyday'";
    if (tag == 'food_frequent_twice_week') mappings[tag] = "value('food_intake_frequency') == 'Twice a week'";
    if (tag == 'food_frequent_once_week') mappings[tag] = "value('food_intake_frequency') == 'Once a week'";
    if (tag == 'food_frequent_others_checked') mappings[tag] = "value('food_intake_frequency') == 'Others'";
    if (tag == 'food_frequent_others') mappings[tag] = "value('food_intake_frequency_other')";

    if (tag == 'food_prepared_home') mappings[tag] = "value('food_prepared_for_mealtime') == 'Prepared at home'";
    if (tag == 'food_bought_outside') mappings[tag] = "value('food_prepared_for_mealtime') == 'Bought outside'";

    if (tag == 'food_bought_frequency_everyday') mappings[tag] = "value('food_preparation_frequency') == 'Everyday'";
    if (tag == 'food_bought_frequency_twice_week') mappings[tag] = "value('food_preparation_frequency') == 'Twice a week'";
    if (tag == 'food_bought_frequency_once_week') mappings[tag] = "value('food_preparation_frequency') == 'Once a week'";
    if (tag == 'food_bought_frequency_others_checked') mappings[tag] = "value('food_preparation_frequency') == 'Others'";

    if (tag == 'bought_food_restaurant_fast_food') mappings[tag] = "value('bought_food_source').contains('Restaurant/Fast food')";
    if (tag == 'bought_food_carinderia') mappings[tag] = "value('bought_food_source').contains('Carinderia')";
    if (tag == 'bought_food_food_cart') mappings[tag] = "value('bought_food_source').contains('Food cart, e.g. fried chicken sa kanto, provent, calamares')";

    if (tag == 'bought_reason_convenient') mappings[tag] = "value('reason_for_bought_food_option').contains('Convenient')";
    if (tag == 'bought_reason_cheaper') mappings[tag] = "value('reason_for_bought_food_option').contains('Cheaper')";
    if (tag == 'bought_reason_healthy') mappings[tag] = "value('reason_for_bought_food_option').contains('Healthy')";
    if (tag == 'bought_reason_variety') mappings[tag] = "value('reason_for_bought_food_option').contains('Variety of choices')";
    if (tag == 'bought_reason_others_checked') mappings[tag] = "value('reason_for_bought_food_option').contains('Others')";
    if (tag == 'bought_reason_others') mappings[tag] = "value('reason_for_bought_food_option_other')";

    if (tag == 'canned_food_everyday') mappings[tag] = "value('canned_preserved_food_frequency') == 'Everyday'";
    if (tag == 'canned_food_every_other_day') mappings[tag] = "value('canned_preserved_food_frequency') == 'Every other day'";
    if (tag == 'canned_food_every_week') mappings[tag] = "value('canned_preserved_food_frequency') == 'Every week'";
    if (tag == 'canned_food_sometimes') mappings[tag] = "value('canned_preserved_food_frequency') == 'Sometimes'";
    if (tag == 'canned_food_never') mappings[tag] = "value('canned_preserved_food_frequency') == 'Never'";

    if (tag == 'grilled_food_everyday') mappings[tag] = "value('grilled_food_frequency') == 'Everyday'";
    if (tag == 'grilled_food_every_other_day') mappings[tag] = "value('grilled_food_frequency') == 'Every other day'";
    if (tag == 'grilled_food_every_week') mappings[tag] = "value('grilled_food_frequency') == 'Every week'";
    if (tag == 'grilled_food_sometimes') mappings[tag] = "value('grilled_food_frequency') == 'Sometimes'";
    if (tag == 'grilled_food_never') mappings[tag] = "value('grilled_food_frequency') == 'Never'";

    if (tag == 'carbonated_everyday') mappings[tag] = "value('carbonated_beverage_frequency') == 'Everyday'";
    if (tag == 'carbonated_every_other_day') mappings[tag] = "value('carbonated_beverage_frequency') == 'Every other day'";
    if (tag == 'carbonated_every_week') mappings[tag] = "value('carbonated_beverage_frequency') == 'Every week'";
    if (tag == 'carbonated_occasionally') mappings[tag] = "value('carbonated_beverage_frequency') == 'Occasionally'";
    if (tag == 'carbonated_sometimes') mappings[tag] = "value('carbonated_beverage_frequency') == 'Sometimes'";
    if (tag == 'carbonated_never') mappings[tag] = "value('carbonated_beverage_frequency') == 'Never'";

    if (tag == 'consulted_doctor') mappings[tag] = "value('personnel_consulted_during_illness').contains('Doctor')";
    if (tag == 'consulted_nurse') mappings[tag] = "value('personnel_consulted_during_illness').contains('Nurse')";
    if (tag == 'consulted_midwife') mappings[tag] = "value('personnel_consulted_during_illness').contains('Midwife')";
    if (tag == 'consulted_hilot') mappings[tag] = "value('personnel_consulted_during_illness').contains('Hilot')";
    if (tag == 'consulted_albularyo') mappings[tag] = "value('personnel_consulted_during_illness').contains('Albularyo')";
    if (tag == 'consulted_faith_healer') mappings[tag] = "value('personnel_consulted_during_illness').contains('Faith Healer')";
    if (tag == 'consulted_elderly') mappings[tag] = "value('personnel_consulted_during_illness').contains('Elderly')";

    if (tag == 'measure_private_health_worker') mappings[tag] = "value('measures_taken_during_illness').contains('Consult a private health worker')";
    if (tag == 'measure_community_healer') mappings[tag] = "value('measures_taken_during_illness').contains('See a known community healer')";
    if (tag == 'measure_rural_health_team') mappings[tag] = "value('measures_taken_during_illness').contains('Consult a Rural Health Team')";
    if (tag == 'measure_self_medication') mappings[tag] = "value('measures_taken_during_illness').contains('Self-Medication')";
    if (tag == 'measure_none') mappings[tag] = "value('measures_taken_during_illness').contains('None')";

    if (tag == 'medication_prescribed_doctor') mappings[tag] = "value('medication_treatment_during_illness').contains('Prescribed by Doctor')";
    if (tag == 'medication_self_medication_otc') mappings[tag] = "value('medication_treatment_during_illness').contains('Self-Medication/OTC drugs')";
    if (tag == 'medication_herbals') mappings[tag] = "value('medication_treatment_during_illness').contains('Herbals')";
    if (tag == 'medication_others_checked') mappings[tag] = "value('medication_treatment_during_illness').contains('Others')";
    if (tag == 'medication_others') mappings[tag] = "value('medication_treatment_during_illness_other')";

    if (tag == 'medical_checkup_once_year') mappings[tag] = "value('medical_checkup_frequency') == 'Once a year'";
    if (tag == 'medical_checkup_twice_year') mappings[tag] = "value('medical_checkup_frequency') == 'Twice a year'";
    if (tag == 'medical_checkup_more_than_year') mappings[tag] = "value('medical_checkup_frequency') == 'More than a year'";

    if (tag == 'dental_checkup_once_year') mappings[tag] = "value('dental_checkup_frequency') == 'Once a year'";
    if (tag == 'dental_checkup_twice_year') mappings[tag] = "value('dental_checkup_frequency') == 'Twice a year'";
    if (tag == 'dental_checkup_more_than_year') mappings[tag] = "value('dental_checkup_frequency') == 'More than a year'";

    if (tag == 'bhc_services_rhu') mappings[tag] = "value('barangay_health_center_services_available').contains('RHU')";
    if (tag == 'bhc_services_bhc') mappings[tag] = "value('barangay_health_center_services_available').contains('BHC')";
    if (tag == 'bhc_services_others_checked') mappings[tag] = "value('barangay_health_center_services_available').contains('Others')";
    if (tag == 'bhc_services_others') mappings[tag] = "value('barangay_health_center_services_available_other')";

    // Leaders, Officials...
    if (tag == 'leader_captain') mappings[tag] = "value('recognized_formal_elected_leaders').contains('Captain')";
    if (tag == 'leader_kagawad') mappings[tag] = "value('recognized_formal_elected_leaders').contains('Kagawad')";
    if (tag == 'leader_elderly') mappings[tag] = "value('recognized_non_formal_leaders').contains('Elderly')";
    if (tag == 'leader_bhw') mappings[tag] = "value('recognized_non_formal_leaders').contains('BHW')";
    if (tag == 'leader_influential_person') mappings[tag] = "value('recognized_non_formal_leaders').contains('Influential person')";
    if (tag == 'leader_religious') mappings[tag] = "value('recognized_non_formal_leaders').contains('Religious leader')";
    if (tag == 'leader_neighbor') mappings[tag] = "value('recognized_non_formal_leaders').contains('Neighbor')";

    if (tag == 'health_budget_available') mappings[tag] = "value('health_budget_expenditures_availability') == 'Available'";
    if (tag == 'health_budget_not_available') mappings[tag] = "value('health_budget_expenditures_availability') == 'Not Available'";
    if (tag == 'health_budget_amount') mappings[tag] = "value('health_budget_amount_per_year_php')";

    if (tag == 'supplies_available_100') mappings[tag] = "value('supplies_equipment_availability') == 'Available 100%'";
    if (tag == 'supplies_limited') mappings[tag] = "value('supplies_equipment_availability') == 'Limited Supplies'";
    if (tag == 'supplies_not_available') mappings[tag] = "value('supplies_equipment_availability') == 'Not Available'";
  }

  // Generate Dart file output
  final out = File('scratch/mapped_fields.dart');
  final sb = StringBuffer();
  for (final tag in tags) {
    if (mappings.containsKey(tag)) {
      sb.writeln("  fields['$tag'] = ${mappings[tag]};");
    }
  }
  out.writeAsStringSync(sb.toString());
  print('Wrote mappings to mapped_fields.dart');
}
