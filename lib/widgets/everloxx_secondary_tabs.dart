import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EverloxxSecondaryTabs extends StatelessWidget
    implements PreferredSizeWidget {
  final List<String> labels;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? labelPadding;

  const EverloxxSecondaryTabs({
    super.key,
    required this.labels,
    this.padding,
    this.labelPadding,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.everloxxTokens;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: tokens.contentMaxWidth),
        child: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding:
              labelPadding ?? const EdgeInsets.symmetric(horizontal: 24),
          padding: padding ??
              EdgeInsets.symmetric(horizontal: tokens.screenPadding),
          labelColor: theme.colorScheme.onSurface,
          unselectedLabelColor:
              theme.colorScheme.onSurface.withValues(alpha:0.6),
          indicatorSize: TabBarIndicatorSize.label,
          indicatorColor: theme.colorScheme.primary,
          tabs: labels.map((t) => Tab(text: t)).toList(),
        ),
      ),
    );
  }
}
