import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';

void main() async {
  final templatePath = 'assets/template/miniword_template.docx';
  final outPath = 'assets/template/miniword_template_fixed.docx';

  final tagMapping = {
    // Services
    'community_services_religious': 'services_in_community=Religious services',
    'community_services_livelihood': 'services_in_community=Livelihood Services',
    'community_services_health': 'services_in_community=Health Services',
    'community_services_garbage': 'services_in_community=Garbage collection',
    'community_services_peace': 'services_in_community=Peace and Order',

    // Institutions
    'institution_brgy_hall': 'institutional_facilities=Brgy. Hall',
    'institution_health_station': 'institutional_facilities=Health Station',
    'institution_church': 'institutional_facilities=Church',
    'institution_school': 'institutional_facilities=School',

    // Traditions
    'tradition_bayanihan': 'traditions_customs=Bayanihan',
    'tradition_palabra_de_honor': 'traditions_customs=Palabra de Honor',
    'tradition_pakikisama': 'traditions_customs=Pakikisama',
    'tradition_ningas_kugon': 'traditions_customs=Ningas Kugon',
    'tradition_fiestas': 'traditions_customs=Fiestas',
    'tradition_close_family_ties': 'traditions_customs=Close family ties',
    'tradition_respect_for_elderly': 'traditions_customs=Respect for elderly',
    'tradition_others_checked': 'traditions_customs=Others',
    'tradition_custom_other': 'traditions_customs_other',
    
    // First food choice
    'first_choice_meat_only': 'first_food_choice=Meat only',
    'first_choice_fish': 'first_food_choice=Fish',
    'first_choice_vegetable': 'first_food_choice=Vegetable',
    'first_choice_mixed': 'first_food_choice=Mixed',
    'first_choice_others_checked': 'first_food_choice=Others',
    
    // Water Source (Drinking)
    'water_drinking_deep_well': 'water_source_drinking=Deep well',
    'water_drinking_local_district': 'water_source_drinking=Local Water District',
    'water_drinking_commercial': 'water_source_drinking=Commercial',
    'water_drinking_others_checked': 'water_source_drinking=Others',

    // Water Source (Cooking)
    'water_cooking_deep_well': 'water_source_cooking=Deep well',
    'water_cooking_local_district': 'water_source_cooking=Local Water District',
    'water_cooking_commercial': 'water_source_cooking=Commercial',
    'water_cooking_others_checked': 'water_source_cooking=Others',

    // Water Source (Bathing)
    'water_bathing_deep_well': 'water_source_bathing_cr_flushing=Deep well',
    'water_bathing_local_district': 'water_source_bathing_cr_flushing=Local Water District',
    'water_bathing_commercial': 'water_source_bathing_cr_flushing=Commercial',
    'water_bathing_others_checked': 'water_source_bathing_cr_flushing=Others',
  };

  final bytes = File(templatePath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  final outArchive = Archive();

  for (final file in archive) {
    if (file.isFile) {
      if (file.name.endsWith('.xml')) {
        String content = String.fromCharCodes(file.content as List<int>);
        tagMapping.forEach((oldTag, newTag) {
          content = content.replaceAll('{{$oldTag}}', '{{$newTag}}');
        });
        outArchive.addFile(ArchiveFile(file.name, content.length, content.codeUnits));
      } else {
        outArchive.addFile(file);
      }
    }
  }

  File(outPath).writeAsBytesSync(ZipEncoder().encode(outArchive)!);
  print('Template updated to miniword_template_fixed.docx');
}
