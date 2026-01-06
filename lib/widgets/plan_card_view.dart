import 'package:flutter/material.dart';

import '../models/plan_models.dart';
import '../theme/app_theme.dart';

class PlanCardView extends StatelessWidget {
  final PlanCardData data;
  final String actionLabel;
  final bool canTap;
  final bool isSelected;
  final VoidCallback? onAction;
  final bool showActionButton;

  const PlanCardView({
    super.key,
    required this.data,
    required this.actionLabel,
    required this.canTap,
    this.isSelected = false,
    this.onAction,
    this.showActionButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    final accent = _planAccentColor(theme, data.id);
    final borderColor = isSelected ? accent : accent.withAlpha(120);
    final shadowColor = borderColor.withAlpha(60);

    final titleStyle = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.05,
    );
    final priceStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.0,
    );
    final priceSubStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(178),
      fontWeight: FontWeight.w600,
      height: 1.1,
    );
    final sublineStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(184),
      fontWeight: FontWeight.w500,
      height: 1.2,
    );
    final featureTitleStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.15,
    );
    final featureDescStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(204),
      height: 1.25,
    );
    final featureValueStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.onSurface,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        color: theme.cardColor.withAlpha(242),
        border: Border.all(color: borderColor, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: EdgeInsets.all(tokens.gapMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: tokens.gapMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.title, style: titleStyle),
                    SizedBox(height: tokens.gapSm),
                    Text(
                      data.subline,
                      style: sublineStyle,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(data.price, style: priceStyle),
                  if ((data.priceSubline ?? '').isNotEmpty) ...[
                    SizedBox(height: tokens.gapXs),
                    Text(data.priceSubline!, style: priceSubStyle),
                  ],
                ],
              ),
            ],
          ),
          SizedBox(height: tokens.gapLg),
          ...data.features.map(
            (f) => Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.gapXs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: Text(f.label, style: featureTitleStyle)),
                      if (f.value != null)
                        Text(f.value!, style: featureValueStyle)
                      else
                        Icon(
                          f.included
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          color: f.included ? Colors.green : Colors.redAccent,
                          size: 20,
                        ),
                    ],
                  ),
                  if ((f.description ?? '').trim().isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: tokens.gapXs / 2),
                      child: Text(f.description!, style: featureDescStyle),
                    ),
                  if ((f.actionLabel ?? '').trim().isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: tokens.gapXs / 2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: f.actionEnabled ? () {} : null,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: theme.colorScheme.primary,
                            textStyle: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(f.actionLabel ?? ''),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (showActionButton && data.showActionButton) ...[
            SizedBox(height: tokens.gapMd),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canTap ? onAction : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canTap
                      ? accent
                      : theme.colorScheme.onSurface.withAlpha(20),
                  foregroundColor: canTap
                      ? _onColorForBackground(accent)
                      : theme.colorScheme.onSurface.withAlpha(160),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.gapMd,
                    vertical: tokens.gapSm,
                  ),
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Color _planAccentColor(ThemeData theme, String id) {
  switch (id) {
    case 'pro':
      return const Color(0xFFD4AF37);
    case 'basic':
    default:
      return theme.colorScheme.primary;
  }
}

Color _onColorForBackground(Color color) {
  final brightness = ThemeData.estimateBrightnessForColor(color);
  return brightness == Brightness.dark ? Colors.white : Colors.black;
}
