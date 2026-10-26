import 'package:flutter/cupertino.dart';

import '../core/theme/tokens.dart';

class CarliSwitch extends StatelessWidget {
  const CarliSwitch({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: context.colors.primary),
    );
  }
}
