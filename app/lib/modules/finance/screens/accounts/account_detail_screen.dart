import 'package:flutter/material.dart';

import '../../../../ui/placeholder_view.dart';

class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) => const PlaceholderView(title: 'Cuenta');
}
