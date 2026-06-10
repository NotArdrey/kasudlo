import 'dart:io';

void main() {
  final missing = [
    'bhc_services_aware', 'bhc_services_unaware', 'bought_food_everyday', 'bought_food_once_week',
    'bought_food_others_checked', 'bought_food_twice_week', 'bought_from_carinderia',
    'bought_from_food_cart', 'bought_from_restaurant_fastfood', 'communication_cellphone',
    'communication_postal', 'community_involvement_active', 'community_involvement_not_active',
    'community_services_garbage_collection', 'community_services_livelihood_duplicate',
    'community_services_peace_order', 'construction_light', 'construction_mixed',
    'construction_strong_concrete', 'consult_albularyo', 'consult_doctor', 'consult_elderly',
    'consult_faith_healer', 'consult_hilot', 'consult_midwife', 'consult_nurse',
    'cooking_sanitary_dirty', 'cooking_sanitary_generally_clean', 'cultural_practices_always',
    'cultural_practices_does_not_practice', 'cultural_practices_sometimes',
    'disposal_not_practiced_burial_pit', 'disposal_not_practiced_collected',
    'disposal_not_practiced_composting', 'disposal_not_practiced_hog_feeding',
    'disposal_not_practiced_open_burning', 'disposal_not_practiced_open_dumping',
    'disposal_practiced_burial_pit', 'disposal_practiced_collected', 'disposal_practiced_composting',
    'disposal_practiced_hog_feeding', 'disposal_practiced_open_burning', 'disposal_practiced_open_dumping',
    'drainage_flowing', 'drainage_stagnant', 'drug_types_checked', 'drug_use_no', 'drug_use_yes',
    'family_composition_blended', 'family_composition_cohabiting_communal', 'family_composition_dyad',
    'family_composition_extended', 'family_composition_living_with_grandparents',
    'family_composition_nuclear', 'family_composition_same_sex', 'family_composition_single_parent',
    'family_descent_bilateral', 'family_descent_matrilineal', 'family_descent_patrilineal',
    'family_power_egalitarian', 'family_power_matricentric', 'family_power_matrifocal_matriarchal',
    'family_power_patrifocal_patriarchal', 'family_residence_bilocal_ambilocal',
    'family_residence_matrilocal', 'family_residence_neolocal', 'family_residence_patrilocal',
    'financial_source_help_relative_friends', 'food_first_fish', 'food_first_meat_only',
    'food_first_mixed', 'food_first_others_checked', 'food_first_serving_1', 'food_first_serving_2_3',
    'food_first_serving_4_5_above', 'food_first_vegetable', 'food_intake_everyday',
    'food_intake_once_week', 'food_intake_others_checked', 'food_intake_twice_week',
    'food_second_fish', 'food_second_meat', 'food_second_mixed', 'food_second_others_checked',
    'food_second_serving_1', 'food_second_serving_2_3', 'food_second_serving_4_5_above',
    'food_second_vegetable', 'fp_acceptor_good_for_health', 'fp_acceptor_others_checked',
    'fp_basal_body_temperature', 'fp_cervical_mucus', 'fp_condoms', 'fp_female_sterilization',
    'fp_fertility_awareness_method', 'fp_implant', 'fp_injectable', 'fp_iud',
    'fp_lactational_amenorrhea', 'fp_male_sterilization', 'fp_nonacceptor_bad_for_health',
    'fp_nonacceptor_influenced_by_others', 'fp_nonacceptor_others_checked',
    'fp_nonacceptor_personal_belief', 'fp_nonacceptor_religious_belief', 'fp_permanent_method',
    'fp_pills', 'fp_standard_days', 'fp_supply_methods', 'fp_sympto_thermal', 'fp_temporary_method',
    'priority_clothing', 'priority_education', 'priority_food', 'priority_health',
    'priority_recreation', 'priority_savings', 'priority_utilities', 'settlement_barangay_hearing',
    'settlement_local_police', 'settlement_others_checked', 'settlement_parties',
    'smoker_frequency_checked', 'smoker_no', 'smoker_yes', 'social_conflict_alcohol',
    'social_conflict_drugs', 'social_conflict_family', 'social_conflict_gossip',
    'social_conflict_others_checked', 'social_conflict_riot'
  ];
  
  final sb = StringBuffer();
  
  void add(String t, String v) {
    sb.writeln("  fields['$t'] = $v;");
  }

  for (final tag in missing) {
    if (tag == 'bhc_services_aware') add(tag, "value('awareness_of_health_services') == 'Aware'");
    if (tag == 'bhc_services_unaware') add(tag, "value('awareness_of_health_services') == 'Unaware'");
    if (tag == 'bought_food_everyday') add(tag, "value('food_preparation_frequency') == 'Everyday'");
    if (tag == 'bought_food_twice_week') add(tag, "value('food_preparation_frequency') == 'Twice a week'");
    if (tag == 'bought_food_once_week') add(tag, "value('food_preparation_frequency') == 'Once a week'");
    if (tag == 'bought_food_others_checked') add(tag, "value('food_preparation_frequency') == 'Others'");
    
    if (tag == 'bought_from_restaurant_fastfood') add(tag, "value('bought_food_source').contains('Restaurant/Fast food')");
    if (tag == 'bought_from_carinderia') add(tag, "value('bought_food_source').contains('Carinderia')");
    if (tag == 'bought_from_food_cart') add(tag, "value('bought_food_source').contains('Food cart')");
    
    if (tag == 'communication_cellphone') add(tag, "value('mode_of_communication').contains('Cell phone')");
    if (tag == 'communication_postal') add(tag, "value('mode_of_communication').contains('Postal system')");
    
    if (tag == 'community_involvement_active') add(tag, "value('community_involvement') == 'Actively joins fiesta, religious procession, local cultural practices'");
    if (tag == 'community_involvement_not_active') add(tag, "value('community_involvement') == 'Does not actively join'");
    
    if (tag == 'community_services_garbage_collection') add(tag, "value('services_in_community').contains('Garbage collection')");
    if (tag == 'community_services_livelihood_duplicate') add(tag, "value('services_in_community').contains('Livelihood Services')");
    if (tag == 'community_services_peace_order') add(tag, "value('services_in_community').contains('Peace and Order')");
    
    if (tag == 'construction_light') add(tag, "value('home_construction_materials') == 'Light'");
    if (tag == 'construction_mixed') add(tag, "value('home_construction_materials') == 'Mixed'");
    if (tag == 'construction_strong_concrete') add(tag, "value('home_construction_materials') == 'Strong/Concrete'");
    
    if (tag == 'consult_doctor') add(tag, "value('personnel_consulted_during_illness').contains('Doctor')");
    if (tag == 'consult_nurse') add(tag, "value('personnel_consulted_during_illness').contains('Nurse')");
    if (tag == 'consult_midwife') add(tag, "value('personnel_consulted_during_illness').contains('Midwife')");
    if (tag == 'consult_hilot') add(tag, "value('personnel_consulted_during_illness').contains('Hilot')");
    if (tag == 'consult_albularyo') add(tag, "value('personnel_consulted_during_illness').contains('Albularyo')");
    if (tag == 'consult_faith_healer') add(tag, "value('personnel_consulted_during_illness').contains('Faith Healer')");
    if (tag == 'consult_elderly') add(tag, "value('personnel_consulted_during_illness').contains('Elderly')");
    
    if (tag == 'cooking_sanitary_generally_clean') add(tag, "value('cooking_area_sanitary_condition') == 'Generally clean'");
    if (tag == 'cooking_sanitary_dirty') add(tag, "value('cooking_area_sanitary_condition') == 'Dirty'");
    
    if (tag == 'cultural_practices_always') add(tag, "value('cultural_perception_health_practices') == 'Always practices local cultural practices about health matters'");
    if (tag == 'cultural_practices_sometimes') add(tag, "value('cultural_perception_health_practices') == 'Sometimes practices local cultural practices about health matters'");
    if (tag == 'cultural_practices_does_not_practice') add(tag, "value('cultural_perception_health_practices') == 'Does not practice any local cultural practices about health matters'");
    
    if (tag == 'disposal_not_practiced_burial_pit') add(tag, "value('waste_disposal_method_if_not_practiced') == 'Burial in pit'");
    if (tag == 'disposal_not_practiced_collected') add(tag, "value('waste_disposal_method_if_not_practiced') == 'Collected'");
    if (tag == 'disposal_not_practiced_composting') add(tag, "value('waste_disposal_method_if_not_practiced') == 'Composting'");
    if (tag == 'disposal_not_practiced_hog_feeding') add(tag, "value('waste_disposal_method_if_not_practiced') == 'Hog-feeding'");
    if (tag == 'disposal_not_practiced_open_burning') add(tag, "value('waste_disposal_method_if_not_practiced') == 'Open burning'");
    if (tag == 'disposal_not_practiced_open_dumping') add(tag, "value('waste_disposal_method_if_not_practiced') == 'Open dumping'");
    
    if (tag == 'disposal_practiced_burial_pit') add(tag, "value('waste_disposal_method_if_practiced') == 'Burial in pit'");
    if (tag == 'disposal_practiced_collected') add(tag, "value('waste_disposal_method_if_practiced') == 'Collected'");
    if (tag == 'disposal_practiced_composting') add(tag, "value('waste_disposal_method_if_practiced') == 'Composting'");
    if (tag == 'disposal_practiced_hog_feeding') add(tag, "value('waste_disposal_method_if_practiced') == 'Hog-feeding'");
    if (tag == 'disposal_practiced_open_burning') add(tag, "value('waste_disposal_method_if_practiced') == 'Open burning'");
    if (tag == 'disposal_practiced_open_dumping') add(tag, "value('waste_disposal_method_if_practiced') == 'Open dumping'");
    
    if (tag == 'drainage_flowing') add(tag, "value('drainage_condition') == 'Flowing'");
    if (tag == 'drainage_stagnant') add(tag, "value('drainage_condition') == 'Stagnant'");
    
    if (tag == 'drug_use_yes') add(tag, "value('family_member_uses_drugs') == 'Yes'");
    if (tag == 'drug_use_no') add(tag, "value('family_member_uses_drugs') == 'No'");
    if (tag == 'drug_types_checked') add(tag, "value('family_member_uses_drugs') == 'Yes'");
    
    if (tag == 'family_composition_nuclear') add(tag, "value('type_of_family_composition') == 'Nuclear'");
    if (tag == 'family_composition_extended') add(tag, "value('type_of_family_composition') == 'Extended'");
    if (tag == 'family_composition_dyad') add(tag, "value('type_of_family_composition') == 'Dyad'");
    if (tag == 'family_composition_same_sex') add(tag, "value('type_of_family_composition') == 'Homosexual/Same Sex'");
    if (tag == 'family_composition_cohabiting_communal') add(tag, "value('type_of_family_composition') == 'Cohabiting/Communal'");
    if (tag == 'family_composition_blended') add(tag, "value('type_of_family_composition') == 'Blended Family'");
    if (tag == 'family_composition_living_with_grandparents') add(tag, "value('type_of_family_composition') == 'Living with Grandparent(s)'");
    if (tag == 'family_composition_single_parent') add(tag, "value('type_of_family_composition') == 'Single- parent'");
    
    if (tag == 'family_descent_patrilineal') add(tag, "value('type_of_family_descent') == 'Patrilineal'");
    if (tag == 'family_descent_matrilineal') add(tag, "value('type_of_family_descent') == 'Matrilineal'");
    if (tag == 'family_descent_bilateral') add(tag, "value('type_of_family_descent') == 'Bilateral'");
    
    if (tag == 'family_power_patrifocal_patriarchal') add(tag, "value('type_of_family_locus_of_power') == 'Patrifocal/Patriarchal'");
    if (tag == 'family_power_matrifocal_matriarchal') add(tag, "value('type_of_family_locus_of_power') == 'Matrifocal/Matriarchal'");
    if (tag == 'family_power_egalitarian') add(tag, "value('type_of_family_locus_of_power') == 'Egalitarian'");
    if (tag == 'family_power_matricentric') add(tag, "value('type_of_family_locus_of_power') == 'Matricentric'");
    
    if (tag == 'family_residence_patrilocal') add(tag, "value('type_of_family_place_of_residence') == 'Patrilocal'");
    if (tag == 'family_residence_matrilocal') add(tag, "value('type_of_family_place_of_residence') == 'Matrilocal'");
    if (tag == 'family_residence_bilocal_ambilocal') add(tag, "value('type_of_family_place_of_residence') == 'Bilocal (Ambilocal)'");
    if (tag == 'family_residence_neolocal') add(tag, "value('type_of_family_place_of_residence') == 'Neolocal'");
    
    if (tag == 'financial_source_help_relative_friends') add(tag, "value('financial_sources').contains('Help from relative/friends')");
    
    if (tag == 'food_first_meat_only') add(tag, "value('first_food_choice') == 'Meat only'");
    if (tag == 'food_first_fish') add(tag, "value('first_food_choice') == 'Fish'");
    if (tag == 'food_first_vegetable') add(tag, "value('first_food_choice') == 'Vegetable'");
    if (tag == 'food_first_mixed') add(tag, "value('first_food_choice') == 'Mixed'");
    if (tag == 'food_first_others_checked') add(tag, "value('first_food_choice') == 'Others'");
    if (tag == 'food_first_serving_1') add(tag, "value('first_food_choice_servings') == '1'");
    if (tag == 'food_first_serving_2_3') add(tag, "value('first_food_choice_servings') == '2-3'");
    if (tag == 'food_first_serving_4_5_above') add(tag, "value('first_food_choice_servings') == '4-5 and above'");
    
    if (tag == 'food_second_meat') add(tag, "value('second_food_choice') == 'Meat'");
    if (tag == 'food_second_fish') add(tag, "value('second_food_choice') == 'Fish'");
    if (tag == 'food_second_vegetable') add(tag, "value('second_food_choice') == 'Vegetable'");
    if (tag == 'food_second_mixed') add(tag, "value('second_food_choice') == 'Mixed'");
    if (tag == 'food_second_others_checked') add(tag, "value('second_food_choice') == 'Others'");
    if (tag == 'food_second_serving_1') add(tag, "value('second_food_choice_servings') == '1'");
    if (tag == 'food_second_serving_2_3') add(tag, "value('second_food_choice_servings') == '2-3'");
    if (tag == 'food_second_serving_4_5_above') add(tag, "value('second_food_choice_servings') == '4-5 and above'");
    
    if (tag == 'food_intake_everyday') add(tag, "value('food_intake_frequency') == 'Everyday'");
    if (tag == 'food_intake_twice_week') add(tag, "value('food_intake_frequency') == 'Twice a week'");
    if (tag == 'food_intake_once_week') add(tag, "value('food_intake_frequency') == 'Once a week'");
    if (tag == 'food_intake_others_checked') add(tag, "value('food_intake_frequency') == 'Others'");
    
    if (tag == 'fp_permanent_method') add(tag, "value('modern_family_planning_method_used') == 'Permanent method'");
    if (tag == 'fp_female_sterilization') add(tag, "value('family_planning_permanent_method') == 'Female sterilization / Bilateral Tubal Ligation'");
    if (tag == 'fp_male_sterilization') add(tag, "value('family_planning_permanent_method') == 'Male sterilization / Vasectomy'");
    if (tag == 'fp_temporary_method') add(tag, "value('modern_family_planning_method_used') == 'Temporary method'");
    if (tag == 'fp_supply_methods') add(tag, "value('family_planning_temporary_method') == 'Supply Methods'");
    if (tag == 'fp_pills') add(tag, "value('family_planning_supply_method') == 'Pills'");
    if (tag == 'fp_iud') add(tag, "value('family_planning_supply_method') == 'IUD'");
    if (tag == 'fp_injectable') add(tag, "value('family_planning_supply_method') == 'Injectable'");
    if (tag == 'fp_condoms') add(tag, "value('family_planning_supply_method') == 'Condoms'");
    if (tag == 'fp_implant') add(tag, "value('family_planning_supply_method') == 'Implant'");
    if (tag == 'fp_fertility_awareness_method') add(tag, "value('family_planning_temporary_method') == 'Fertility Awareness-Based Method'");
    if (tag == 'fp_cervical_mucus') add(tag, "value('family_planning_fertility_awareness_method') == 'Cervical Mucus Method / Billings Ovu. Method'");
    if (tag == 'fp_basal_body_temperature') add(tag, "value('family_planning_fertility_awareness_method') == 'Basal Body Temperature (BBT)'");
    if (tag == 'fp_sympto_thermal') add(tag, "value('family_planning_fertility_awareness_method') == 'Sympto-Thermal Method'");
    if (tag == 'fp_standard_days') add(tag, "value('family_planning_fertility_awareness_method') == 'Standard Days Method (SDM)'");
    if (tag == 'fp_lactational_amenorrhea') add(tag, "value('family_planning_fertility_awareness_method') == 'Lactational Amenorrhea Method (LAM)'");
    
    if (tag == 'fp_acceptor_good_for_health') add(tag, "value('reason_for_using_family_planning_method').contains('Good for health')");
    if (tag == 'fp_acceptor_others_checked') add(tag, "value('reason_for_using_family_planning_method').contains('Others')");
    
    if (tag == 'fp_nonacceptor_bad_for_health') add(tag, "value('reason_for_not_using_family_planning_method').contains('Bad for health')");
    if (tag == 'fp_nonacceptor_personal_belief') add(tag, "value('reason_for_not_using_family_planning_method').contains('Personal belief')");
    if (tag == 'fp_nonacceptor_religious_belief') add(tag, "value('reason_for_not_using_family_planning_method').contains('Religious belief')");
    if (tag == 'fp_nonacceptor_influenced_by_others') add(tag, "value('reason_for_not_using_family_planning_method').contains('Influenced by others')");
    if (tag == 'fp_nonacceptor_others_checked') add(tag, "value('reason_for_not_using_family_planning_method').contains('Others')");
    
    if (tag == 'priority_food') add(tag, "value('priorities_and_expenditure_ranking').contains('1. Food') || value('priorities_and_expenditure_ranking').contains('Food')");
    if (tag == 'priority_clothing') add(tag, "value('priorities_and_expenditure_ranking').contains('Clothing')");
    if (tag == 'priority_education') add(tag, "value('priorities_and_expenditure_ranking').contains('Education')");
    if (tag == 'priority_utilities') add(tag, "value('priorities_and_expenditure_ranking').contains('Utilities')");
    if (tag == 'priority_health') add(tag, "value('priorities_and_expenditure_ranking').contains('Health')");
    if (tag == 'priority_recreation') add(tag, "value('priorities_and_expenditure_ranking').contains('Recreation')");
    if (tag == 'priority_savings') add(tag, "value('priorities_and_expenditure_ranking').contains('Savings')");
    
    if (tag == 'settlement_barangay_hearing') add(tag, "value('effective_practices_setting_issues').contains('Brgy. hearing')");
    if (tag == 'settlement_parties') add(tag, "value('effective_practices_setting_issues').contains('Settlement among involved parties')");
    if (tag == 'settlement_local_police') add(tag, "value('effective_practices_setting_issues').contains('Endorsed to local police')");
    if (tag == 'settlement_others_checked') add(tag, "value('effective_practices_setting_issues').contains('Others')");
    
    if (tag == 'smoker_yes') add(tag, "value('family_member_is_cigarette_smoker') == 'Yes'");
    if (tag == 'smoker_no') add(tag, "value('family_member_is_cigarette_smoker') == 'No'");
    if (tag == 'smoker_frequency_checked') add(tag, "value('family_member_is_cigarette_smoker') == 'Yes'");
    
    if (tag == 'social_conflict_drugs') add(tag, "value('source_of_social_conflict').contains('Drugs')");
    if (tag == 'social_conflict_alcohol') add(tag, "value('source_of_social_conflict').contains('Alcohol')");
    if (tag == 'social_conflict_riot') add(tag, "value('source_of_social_conflict').contains('Riot')");
    if (tag == 'social_conflict_family') add(tag, "value('source_of_social_conflict').contains('Family dispute')");
    if (tag == 'social_conflict_gossip') add(tag, "value('source_of_social_conflict').contains('Gossip')");
    if (tag == 'social_conflict_others_checked') add(tag, "value('source_of_social_conflict').contains('Others')");
  }

  File('scratch/missing_fields_mapped.dart').writeAsStringSync(sb.toString());
}
