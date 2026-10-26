import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';

class CarliSkeleton extends StatefulWidget {
  const CarliSkeleton({super.key, this.width, this.height = 16, this.radius = CarliRadius.sm});

  const CarliSkeleton.circle({super.key, double size = 36}) : width = size, height = size, radius = CarliRadius.full;

  final double? width;
  final double height;
  final double radius;

  @override
  State<CarliSkeleton> createState() => _CarliSkeletonState();
}

class _CarliSkeletonState extends State<CarliSkeleton> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween(begin: 0.5, end: 1.0).animate(_pulse),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(color: context.colors.surface2, borderRadius: BorderRadius.circular(widget.radius)),
        ),
      ),
    );
  }
}
