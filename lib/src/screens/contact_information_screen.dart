import 'package:flutter/material.dart';

import '../widgets/app_chrome.dart';

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
              const SizedBox(height: 12),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.phone),
                title: Text('Emergency Hotline'),
                subtitle: Text('911'),
              ),
              const Divider(height: 1),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.local_hospital),
                title: Text('Health Center'),
                subtitle: Text('(123) 456-7890'),
              ),
              const Divider(height: 1),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.email),
                title: Text('Email Support'),
                subtitle: Text('support@kasudlo.app'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
