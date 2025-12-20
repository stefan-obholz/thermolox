import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ThermoloxSegmentedTabs extends StatelessWidget
    implements PreferredSizeWidget {
  final List<String> labels;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? tabPadding;
  final bool fill;

  const ThermoloxSegmentedTabs({
    super.key,
    required this.labels,
    this.margin,
    this.tabPadding,
    this.fill = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    final resolvedMargin = margin ??
        EdgeInsets.fromLTRB(
          tokens.screenPadding,
          tokens.gapSm,
          tokens.screenPadding,
          tokens.gapSm,
        );
    final resolvedTabPadding = tabPadding ??
        (fill
            ? const EdgeInsets.symmetric(horizontal: 12)
            : const EdgeInsets.symmetric(horizontal: 22));
    final tabHeight = tokens.segmentedTabHeight;

    final isScrollable = !fill;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: tokens.contentMaxWidth),
        child: Container(
          margin: resolvedMargin,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.55),
            ),
          ),
          child: TabBar(
            isScrollable: isScrollable,
            tabAlignment:
                isScrollable ? TabAlignment.start : TabAlignment.fill,
            labelPadding: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              for (final label in labels)
                Tab(
                  child: SizedBox(
                    height: tabHeight,
                    child: Center(
                      child: Padding(
                        padding: resolvedTabPadding,
                        child: fill
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              )
                            : Text(label),
                      ),
                    ),
                  ),
                ),
            ],
            indicator: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(tokens.radiusPill),
            ),
            labelStyle: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: theme.textTheme.bodyMedium,
            labelColor: theme.colorScheme.onPrimary,
            unselectedLabelColor:
                theme.colorScheme.onSurface.withOpacity(0.75),
            dividerColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}
