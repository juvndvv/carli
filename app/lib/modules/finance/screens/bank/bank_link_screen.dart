import 'package:flutter/material.dart';

import '../../../../ui/placeholder_view.dart';

class BankLinkScreen extends StatelessWidget {
  const BankLinkScreen({super.key, required this.connectionId});

  final String connectionId;

  @override
  Widget build(BuildContext context) => const PlaceholderView(title: 'Vincular banco');
}
