import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'chat_models.dart';

class QuickReplyChip extends StatelessWidget {
  final QuickReplyButton button;
  final VoidCallback onTap;

  const QuickReplyChip({required this.button, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.everloxxTokens;
    final isPreferred = button.preferred;

    final background = isPreferred ? theme.colorScheme.primary : Colors.white;
    final foreground = isPreferred
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.primary;

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: background,
        foregroundColor: foreground,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          side: BorderSide(
            color: isPreferred
                ? background
                : theme.colorScheme.primary.withAlpha(217),
            width: 1.3,
          ),
        ),
        overlayColor: theme.colorScheme.primary.withAlpha(20),
      ),
      child: Text(
        button.label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ColorSwatchChip extends StatelessWidget {
  final String hex;
  final Color color;
  final VoidCallback onTap;

  const ColorSwatchChip({
    required this.hex,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.everloxxTokens;
    final labelColor = theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.onSurface.withAlpha(36),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.gapXs),
          Text(
            hex,
            style: theme.textTheme.bodySmall?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
///  EVERLOXX KREIS-WIDGET (Kamera / Galerie / Datei)
/// =======================

class AttachmentActionCircle extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const AttachmentActionCircle({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<AttachmentActionCircle> createState() =>
      AttachmentActionCircleState();
}

class AttachmentActionCircleState extends State<AttachmentActionCircle>
    with TickerProviderStateMixin {
  late final AnimationController _rotationCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    final tokens = EverloxxTokens.light;
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: tokens.ringRotationDuration,
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: tokens.ringPulseDuration,
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.everloxxTokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.04).animate(
            CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
          ),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(166),
                    blurRadius: 26,
                    spreadRadius: 3,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // rotierender Ring
                  RotationTransition(
                    turns: _rotationCtrl,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: tokens.rainbowRingGradient,
                        boxShadow: [
                          BoxShadow(
                            color: tokens.rainbowRingHaloColor,
                            blurRadius: tokens.rainbowRingHaloBlur,
                            spreadRadius: tokens.rainbowRingHaloSpread,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // innerer Kreis
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
                  // Icon
                  Icon(widget.icon, size: 30, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// =======================
///  REGENBOGEN-BUROKLAMMER
/// =======================

class AttachmentIconButton extends StatefulWidget {
  final VoidCallback onTap;

  const AttachmentIconButton({required this.onTap});

  @override
  State<AttachmentIconButton> createState() => AttachmentIconButtonState();
}

class AttachmentIconButtonState extends State<AttachmentIconButton>
    with TickerProviderStateMixin {
  late final AnimationController _rotationCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    final tokens = EverloxxTokens.light;

    _rotationCtrl = AnimationController(
      vsync: this,
      duration: tokens.ringRotationDuration,
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: tokens.ringPulseDuration,
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.everloxxTokens;

    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.96,
        end: 1.04,
      ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut)),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(153),
                blurRadius: 20,
                spreadRadius: 3,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // rotierender Ring
              RotationTransition(
                turns: _rotationCtrl,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: tokens.rainbowRingGradient,
                    boxShadow: [
                      BoxShadow(
                        color: tokens.rainbowRingHaloColor,
                        blurRadius: tokens.rainbowRingHaloBlurSm,
                        spreadRadius: tokens.rainbowRingHaloSpreadSm,
                      ),
                    ],
                  ),
                ),
              ),
              // innerer Kreis
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.scaffoldBackgroundColor,
                ),
              ),
              // Icon
              Transform.rotate(
                angle: 0.25 * math.pi, // 0.25 = 45°, 0.5 = 90°, usw.
                child: Icon(
                  Icons.attach_file,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                  weight: 800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kleine iMessage-artige Aufpopp-Animation fuer jede Bubble.
class ChatBubbleAnimated extends StatefulWidget {
  final Widget child;
  final bool isUser;

  const ChatBubbleAnimated({
    super.key,
    required this.child,
    required this.isUser,
  });

  @override
  State<ChatBubbleAnimated> createState() => ChatBubbleAnimatedState();
}

class ChatBubbleAnimatedState extends State<ChatBubbleAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final tokens = EverloxxTokens.light;
    _controller = AnimationController(
      vsync: this,
      duration: tokens.bubbleIntroDuration,
    );

    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    final beginOffset = widget.isUser
        ? const Offset(0.1, 0.05)
        : const Offset(-0.1, 0.05);
    _slide = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

class RenderDots extends StatefulWidget {
  final Color color;

  const RenderDots({required this.color});

  @override
  State<RenderDots> createState() => RenderDotsState();
}

class RenderDotsState extends State<RenderDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (_controller.value * 2 * math.pi) +
                (index * 0.8);
            final scale = 0.6 + (math.sin(phase).abs() * 0.4);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class RenderProgressBar extends StatefulWidget {
  const RenderProgressBar();

  @override
  State<RenderProgressBar> createState() => RenderProgressBarState();
}

class RenderProgressBarState extends State<RenderProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = Curves.easeInOut.transform(_controller.value);
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 6,
            color: baseColor.withValues(alpha: 0.2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(color: baseColor),
              ),
            ),
          ),
        );
      },
    );
  }
}
