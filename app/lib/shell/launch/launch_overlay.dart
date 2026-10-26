import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/biometric_lock.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../ui/logo.dart';

enum _Phase { holding, playing, fading, gone }

class LaunchOverlay extends ConsumerStatefulWidget {
  const LaunchOverlay({super.key});

  static const duration = Duration(milliseconds: 1500);
  static const faceSize = 96.0;

  @override
  ConsumerState<LaunchOverlay> createState() => _LaunchOverlayState();
}

class _LaunchOverlayState extends ConsumerState<LaunchOverlay> with TickerProviderStateMixin {
  late final _play = AnimationController(vsync: this, duration: LaunchOverlay.duration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _fadeOut();
    });
  late final _fade = AnimationController(vsync: this, duration: CarliMotion.fade, value: 1)
    ..addStatusListener((status) {
      if (status == AnimationStatus.dismissed) setState(() => _phase = _Phase.gone);
    });

  var _phase = _Phase.holding;

  @override
  void dispose() {
    _play.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _start() {
    if (_phase != _Phase.holding) return;
    final lock = ref.read(biometricLockProvider);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (lock.locked || reducedMotion) {
      setState(() => _phase = _Phase.gone);
      return;
    }
    setState(() => _phase = _Phase.playing);
    _play.forward();
  }

  void _fadeOut() {
    if (_phase == _Phase.fading || _phase == _Phase.gone) return;
    setState(() => _phase = _Phase.fading);
    _play.stop();
    _fade.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.gone) return const SizedBox.shrink();

    final ready =
        ref.watch(authControllerProvider) is! AuthUnknown &&
        ref.watch(biometricLockProvider.select((lock) => lock.ready && !lock.busy));
    if (ready && _phase == _Phase.holding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start();
      });
    }

    final colors = context.colors;
    return Semantics(
      label: 'carli',
      button: _phase == _Phase.playing,
      onTap: _phase == _Phase.playing ? _fadeOut : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _phase == _Phase.playing ? _fadeOut : null,
        child: FadeTransition(
          opacity: _fade,
          child: ColoredBox(
            color: colors.bg,
            child: AnimatedBuilder(
              animation: _play,
              builder: (context, _) => _LaunchFrame(progress: _play.value),
            ),
          ),
        ),
      ),
    );
  }
}

class _LaunchFrame extends StatelessWidget {
  const _LaunchFrame({required this.progress});

  final double progress;

  static const _blinks = [(0.30, 0.40), (0.48, 0.58)];

  double get _eyeOpenness {
    for (final (start, end) in _blinks) {
      if (progress >= start && progress <= end) {
        final t = (progress - start) / (end - start);
        return (2 * t - 1).abs();
      }
    }
    return 1;
  }

  double get _wordmark => Curves.easeOut.transform(((progress - 0.15) / 0.3).clamp(0, 1));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      alignment: Alignment.center,
      children: [
        CarliLogo(size: LaunchOverlay.faceSize, eyeOpenness: _eyeOpenness),
        Transform.translate(
          offset: Offset(0, LaunchOverlay.faceSize / 2 + 28 + 6 * (1 - _wordmark)),
          child: Opacity(
            opacity: _wordmark,
            child: Text(
              'carli',
              style: CarliType.h1.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation.weight(650)],
                letterSpacing: -0.03 * 22,
                color: colors.text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
