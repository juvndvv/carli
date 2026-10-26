import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

typedef CarliIconData = List<List<dynamic>>;

class CarliIcon extends StatelessWidget {
  const CarliIcon(this.icon, {super.key, this.size = 20, this.color, this.strokeWidth = 1.5});

  final CarliIconData icon;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => HugeIcon(icon: icon, size: size, color: color, strokeWidth: strokeWidth);
}
