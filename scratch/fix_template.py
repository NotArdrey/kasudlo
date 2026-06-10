import zipfile
import re
import os
import shutil

template_path = r'e:\Codes\kasudlo\assets\template\miniword_template.docx'
out_path = r'e:\Codes\kasudlo\assets\template\miniword_template_fixed.docx'

# Mappings of custom tags in the document to the auto-generated tags in report_exporter.dart
tag_mapping = {
    # Services
    "community_services_religious": "services_in_community=Religious services",
    "community_services_livelihood": "services_in_community=Livelihood Services",
    "community_services_health": "services_in_community=Health Services",
    "community_services_garbage": "services_in_community=Garbage collection",
    "community_services_peace": "services_in_community=Peace and Order",

    # Institutions
    "institution_brgy_hall": "institutional_facilities=Brgy. Hall",
    "institution_health_station": "institutional_facilities=Health Station",
    "institution_church": "institutional_facilities=Church",
    "institution_school": "institutional_facilities=School",

    # Organizations
    "organization_senior_citizen": "organizations=Senior Citizen",
    "organization_youth": "organizations=Youth",
    "organization_others_checked": "organizations=Others",
    "org_others": "organizations_other",

    # Traditions
    "tradition_bayanihan": "traditions_customs=Bayanihan",
    "tradition_palabra_de_honor": "traditions_customs=Palabra de Honor",
    "tradition_pakikisama": "traditions_customs=Pakikisama",
    "tradition_ningas_kugon": "traditions_customs=Ningas Kugon",
    "tradition_fiestas": "traditions_customs=Fiestas",
    "tradition_close_family_ties": "traditions_customs=Close family ties",
    "tradition_respect_for_elderly": "traditions_customs=Respect for elderly",
    "tradition_others_checked": "traditions_customs=Others",
    "tradition_custom_other": "traditions_customs_other",

    # Recreational
    "recreation_basketball_volleyball_court": "recreational_facilities=Volleyball/Basketball court",
    "recreation_playground": "recreational_facilities=Playground",
    "recreation_plaza": "recreational_facilities=Plaza",
    "recreation_others_checked": "recreational_facilities=Others",
    "recreational_others": "recreational_facilities_other",

    # Transportation
    "transport_tricycle": "mode_of_transportation=Tricycle",
    "transport_jeep": "mode_of_transportation=Jeep",
    "transport_puj_puv": "mode_of_transportation=PUJ/PUV",
    "transport_bicycle": "mode_of_transportation=Bicycle",
    "transport_private_vehicle": "mode_of_transportation=Private vehicle",

    # Communication
    "communication_postal_system": "mode_of_communication=Postal system",
    "communication_internet": "mode_of_communication=Internet",
    "communication_telephone": "mode_of_communication=Telephone",
    "communication_cell_phone": "mode_of_communication=Cell phone",
    "communication_two_way_radio": "mode_of_communication=Two-way radio",
    "communication_others_checked": "mode_of_communication=Others",
    "communication_other": "mode_of_communication_other",

    # Leaders
    "leader_captain": "recognized_formal_elected_leaders=Captain",
    "leader_kagawad": "recognized_formal_elected_leaders=Kagawad",
    "leader_elderly": "recognized_non_formal_leaders=Elderly",
    "leader_bhw": "recognized_non_formal_leaders=BHW",
    "leader_influential_person": "recognized_non_formal_leaders=Influential person",
    "leader_religious": "recognized_non_formal_leaders=Religious leader",
    "leader_neighbor": "recognized_non_formal_leaders=Neighbor",

    # And we can do more if needed...
}

def replace_in_xml(xml_content):
    content_str = xml_content.decode('utf-8')
    for old_tag, new_tag in tag_mapping.items():
        content_str = content_str.replace('{{' + old_tag + '}}', '{{' + new_tag + '}}')
    return content_str.encode('utf-8')

with zipfile.ZipFile(template_path, 'r') as zin:
    with zipfile.ZipFile(out_path, 'w') as zout:
        for item in zin.infolist():
            content = zin.read(item.filename)
            if item.filename.endswith('.xml'):
                content = replace_in_xml(content)
            zout.writestr(item, content)

print("Template updated. Replaced custom tags with correct schema-based tags.")
