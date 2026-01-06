import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/thermolox_overlay.dart';

class BeforeAfterSlider extends StatefulWidget {
  final Widget before;
  final Widget after;
  final double initialFraction;
  final BorderRadius? borderRadius;

  const BeforeAfterSlider({
    super.key,
    required this.before,
    required this.after,
    this.initialFraction = 0.5,
    this.borderRadius,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  late double _fraction;

  @override
  void initState() {
    super.initState();
    _fraction = widget.initialFraction.clamp(0.05, 0.95);
  }

  void _update(Offset localPosition, double width) {
    setState(() {
      _fraction = (localPosition.dx / width).clamp(0.05, 0.95);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    final borderRadius =
        widget.borderRadius ?? BorderRadius.circular(tokens.radiusMd);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final handleX = width * _fraction;

        return GestureDetector(
          onTapDown: (details) => _update(details.localPosition, width),
          onHorizontalDragUpdate: (details) =>
              _update(details.localPosition, width),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              children: [
                Positioned.fill(child: widget.before),
                Positioned.fill(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: _fraction,
                      child: widget.after,
                    ),
                  ),
                ),
                Positioned(
                  left: handleX - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Positioned(
                  left: handleX - 16,
                  top: (height / 2) - 16,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.drag_handle,
                      color: theme.colorScheme.onSurface,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> showBeforeAfterDialog({
  required BuildContext context,
  required Widget before,
  required Widget after,
}) async {
  final tokens = context.thermoloxTokens;
  await ThermoloxOverlay.showAppDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.85)),
            ),
            Center(
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(tokens.screenPadding),
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: BeforeAfterSlider(
                          before: before,
                          after: after,
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
