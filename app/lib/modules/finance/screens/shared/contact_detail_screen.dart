import 'package:flutter/material.dart';

import '../../../../ui/placeholder_view.dart';

class ContactDetailScreen extends StatelessWidget {
  const ContactDetailScreen({super.key, required this.contactId});

  final String contactId;

  @override
  Widget build(BuildContext context) => const PlaceholderView(title: 'Contacto');
}
