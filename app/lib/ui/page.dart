import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';

class CarliPage extends StatelessWidget {
  const CarliPage({
    super.key,
    required this.title,
    required this.slivers,
    this.trailing,
    this.onRefresh,
    this.bottomInset = 150,
  });

  final String title;
  final List<Widget> slivers;
  final Widget? trailing;
  final Future<void> Function()? onRefresh;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title, style: CarliType.h1.copyWith(color: colors.text)),
            middle: Text(title, style: CarliType.h2.copyWith(color: colors.text)),
            alwaysShowMiddle: false,
            trailing: trailing,
            backgroundColor: colors.bg.withValues(alpha: 0.85),
            border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
            transitionBetweenRoutes: false,
          ),
          if (onRefresh case final refresh?) CupertinoSliverRefreshControl(onRefresh: refresh),
          ...slivers,
          SliverPadding(padding: EdgeInsets.only(bottom: bottomInset + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}

class CarliSection extends StatelessWidget {
  const CarliSection({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s16, CarliSpace.s16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s8,
        children: [
          if (title case final title?)
            Semantics(
              header: true,
              child: Text(title.toUpperCase(), style: CarliType.eyebrow.copyWith(color: colors.text3)),
            ),
          child,
        ],
      ),
    );
  }
}
