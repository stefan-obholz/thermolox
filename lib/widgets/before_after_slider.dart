import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/thermolox_overlay.dart';

class BeforeAfterSlider extends StatefulWidget {
  final Widget before;
  final Widget after;
  final double initialFraction;
  final BorderRadius? borderRadius;
  final bool showArrows;

  const BeforeAfterSlider({
    super.key,
    required this.before,
    required this.after,
    this.initialFraction = 0.5,
    this.borderRadius,
    this.showArrows = true,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  late double _fraction;

  @override
  void initState() {
    super.initState();
    _fraction = widget.initialFraction.clamp(0.0, 1.0);
  }

  void _onChanged(double value) {
    setState(() {
      _fraction = value.clamp(0.0, 1.0);
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
        final percent = _fraction.clamp(0.0, 1.0);
        final handleX = width * percent;
        const double buttonSize = 40;
        const double buttonGap = 10;
        final clampedX = handleX.clamp(0.0, width);

        return ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: widget.before),
              Positioned.fill(
                child: ClipPath(
                  clipper: _RevealClipper(percent: percent),
                  child: widget.after,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CenterLinePainter(
                      x: clampedX,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
              if (widget.showArrows) ...[
                Positioned(
                  left: (clampedX - buttonGap - buttonSize)
                      .clamp(0.0, width - buttonSize),
                  top: (constraints.maxHeight - buttonSize) / 2,
                  child: const _ArrowButton(
                    icon: Icons.chevron_left,
                    size: buttonSize,
                  ),
                ),
                Positioned(
                  left: (clampedX + buttonGap)
                      .clamp(0.0, width - buttonSize),
                  top: (constraints.maxHeight - buttonSize) / 2,
                  child: const _ArrowButton(
                    icon: Icons.chevron_right,
                    size: buttonSize,
                  ),
                ),
              ],
              Positioned.fill(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 0,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.transparent,
                    overlayColor: Colors.transparent,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 0),
                  ),
                  child: Slider(
                    min: 0,
                    max: 1,
                    value: percent,
                    onChanged: _onChanged,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CenterLinePainter extends CustomPainter {
  final double x;
  final Color color;

  const _CenterLinePainter({required this.x, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _CenterLinePainter oldDelegate) =>
      oldDelegate.x != x || oldDelegate.color != color;
}

class _RevealClipper extends CustomClipper<Path> {
  final double percent;

  _RevealClipper({required double percent})
      : percent = percent.clamp(0.0, 1.0);

  @override
  Path getClip(Size size) {
    final width = size.width * percent;
    return Path()..addRect(Rect.fromLTWH(0, 0, width, size.height));
  }

  @override
  bool shouldReclip(covariant _RevealClipper oldClipper) =>
      oldClipper.percent != percent;
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final double size;

  const _ArrowButton({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.black87),
    );
  }
}

Future<void> showBeforeAfterDialog({
  required BuildContext context,
  required Widget before,
  required Widget after,
  double? aspectRatio,
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
                  child: Material(
                    color: Colors.transparent,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final ratio = (aspectRatio != null && aspectRatio > 0)
                            ? aspectRatio
                            : 4 / 3;
                        var height = constraints.maxHeight;
                        var width = height * ratio;
                        if (width > constraints.maxWidth) {
                          width = constraints.maxWidth;
                          height = width / ratio;
                        }
                        return Stack(
                          children: [
                            Center(
                              child: SizedBox(
                                width: width,
                                height: height,
                                child: BeforeAfterSlider(
                                  before: before,
                                  after: after,
                                  borderRadius:
                                      BorderRadius.circular(tokens.radiusSm),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
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
