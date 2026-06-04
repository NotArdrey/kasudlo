import 'package:flutter/material.dart';

import '../widgets/app_chrome.dart';

class _StudentContact {
  final String name;
  final String address;
  final String phone;
  final String email;
  final String guardianName;
  final String guardianPhone;

  const _StudentContact({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.guardianName,
    required this.guardianPhone,
  });
}

const _contacts = [
  _StudentContact(
    name: 'De Belen, Mikaela Angela Nicole B.',
    address: '140 Dr. Guizano St. Capihan, San Rafael, Bulacan',
    phone: '09424522767',
    email: 'mikaelaangela.debelen@gmail.com',
    guardianName: 'Nanette B. De Belen',
    guardianPhone: '09228777357',
  ),
  _StudentContact(
    name: 'Desacula, Neil Jay S.',
    address: 'Tanawan, Bustos, Bulacan',
    phone: '09515889541',
    email: 'neilaydesacula2319@gmail.com',
    guardianName: 'Joselyn S. Santos',
    guardianPhone: '09331748707',
  ),
  _StudentContact(
    name: 'Santos, Sheree Marie N.',
    address: 'Tanawan, Bustos, Bulacan',
    phone: '09361085967',
    email: 'shereemariesantos36@gmail.com',
    guardianName: 'Joselyn S. Santos',
    guardianPhone: '09331748707',
  ),
  _StudentContact(
    name: 'Saplala, Alyna Mae A.',
    address: 'San Juan, San Miguel, Bulacan',
    phone: '0956 457 6702',
    email: 'alynasaplala@gmail.com',
    guardianName: 'Alex Saplala',
    guardianPhone: '0956 573 2520',
  ),
  _StudentContact(
    name: 'Soliman, Jean Carmela G.',
    address: '612 Maharlika St. Inaon, Pulilan, Bulacan',
    phone: '09694731142',
    email: 'solimanjeancarmela@gmail.com',
    guardianName: 'Digna G. Soliman',
    guardianPhone: '09231239597',
  ),
  _StudentContact(
    name: 'Tañala, Rheann Jane P.',
    address: 'Looban Bigte, Norzagaray, Bulacan',
    phone: '09616613948',
    email: 'rheannjanetanala@gmail.com',
    guardianName: 'Ma. Annie S. Tañala',
    guardianPhone: '09215900899',
  ),
  _StudentContact(
    name: 'Tibayan, Julia Faye D.',
    address: '099 Luwasan St., Illescas Rd., Binagbag, Angat, Bul.',
    phone: '0946 624 3568',
    email: 'juliafayetibayan@gmail.com',
    guardianName: 'Melinda Tibayan',
    guardianPhone: '09516402598',
  ),
  _StudentContact(
    name: 'Trinidad, Ellayza Rian S.',
    address: '141 Purok 1 Dalayap, Candaba, Pampanga',
    phone: '09060622831',
    email: 'llyzrntrinidad@gmail.com',
    guardianName: 'Evangeline S. Trinidad',
    guardianPhone: '0995 897 2014',
  ),
  _StudentContact(
    name: 'Vasallo, Ron Harry V.',
    address: 'Pantubig, San Rafael, Bulacan',
    phone: '09163221784',
    email: 'ronharryvasallo@gmail.com',
    guardianName: 'Cynthia Vasallo',
    guardianPhone: '09980049380',
  ),
  _StudentContact(
    name: 'Velasco, Tricia Mae P.',
    address: 'Bagong Barrio St., Pinaod, San Ildefonso, Bulacan',
    phone: '0926 573 2940',
    email: 'triciamaevelasco8@gmail.com',
    guardianName: 'Siony P. Velasco',
    guardianPhone: '0935 140 5105',
  ),
];

class ContactInformationScreen extends StatelessWidget {
  const ContactInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Contact Information',
      subtitle: 'Get in touch with health nurses and emergency services',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Important Contacts', style: Theme.of(context).textTheme.titleMedium),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.email),
                title: Text('Email Support'),
                subtitle: Text('kasudlo.med@gmail.com'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Team Members', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ..._contacts.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _ContactRow(icon: Icons.location_on, text: c.address),
                const SizedBox(height: 8),
                _ContactRow(icon: Icons.phone, text: c.phone),
                const SizedBox(height: 8),
                _ContactRow(icon: Icons.email, text: c.email),
                const Divider(height: 24),
                Text('Guardian / Parent', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                _ContactRow(icon: Icons.person, text: c.guardianName),
                const SizedBox(height: 8),
                _ContactRow(icon: Icons.phone_android, text: c.guardianPhone),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.text});
  
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
