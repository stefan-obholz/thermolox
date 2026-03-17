import 'package:flutter/material.dart';

class FeatureGuard extends StatelessWidget {
  final Widget Function() builder;
  final String message;

  const FeatureGuard({
    super.key,
    required this.builder,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return builder();
    } catch (_) {
      return _FeatureFallback(message: message);
    }
  }
}

class _FeatureFallback extends StatelessWidget {
  final String message;

  const _FeatureFallback({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}
