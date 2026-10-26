import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'module_switcher.dart';
import 'pressable.dart';

class CarliPage extends StatelessWidget {
  const CarliPage({
    super.key,
    required this.title,
    required this.slivers,
    this.leading,
    this.moduleSwitcher = false,
    this.trailing,
    this.onRefresh,
    this.bottomInset = 150,
  });

  final String title;
  final List<Widget> slivers;
  final Widget? leading;

  /// Tab roots show the module switcher at the top left.
  final bool moduleSwitcher;
  final Widget? trailing;
  final Future<void> Function()? onRefresh;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final leading = this.leading ?? (moduleSwitcher ? const ModuleSwitcher() : null);
    return Scaffold(
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title, style: CarliType.h1.copyWith(color: colors.text)),
            middle: Text(title, style: CarliType.h2.copyWith(color: colors.text)),
            alwaysShowMiddle: false,
            leading: leading,
            automaticallyImplyLeading: leading == null,
            trailing: trailing,
            backgroundColor: colors.bg.withValues(alpha: 0.85),
            border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
            transitionBetweenRoutes: false,
          ),
          if (onRefresh case final refresh?) CupertinoSliverRefreshControl(onRefresh: refresh),
          const SliverToBoxAdapter(child: SizedBox(height: CarliSpace.s12)),
          ...slivers,
          SliverPadding(padding: EdgeInsets.only(bottom: bottomInset + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}

class CarliSection extends StatelessWidget {
  const CarliSection({super.key, this.title, required this.child, this.actionLabel, this.onAction});

  final String? title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s24, CarliSpace.s16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s8,
        children: [
          if (title case final title?) CarliSectionHeader(title: title, actionLabel: actionLabel, onAction: onAction),
          child,
        ],
      ),
    );
  }
}

/// Fitness-style section title: 22 pt bold in sentence case, with an optional "Ver todos" link.
class CarliSectionHeader extends StatelessWidget {
  const CarliSectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: CarliType.title2.copyWith(color: colors.text)),
          ),
        ),
        if (actionLabel case final label?)
          Semantics(
            button: true,
            child: Pressable(
              onTap: onAction,
              child: Text(label, style: CarliType.body.copyWith(color: colors.brandInk)),
            ),
          ),
      ],
    );
  }
}
