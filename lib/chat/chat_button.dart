import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'chat_bot.dart';

class ThermoloxChatButton extends StatefulWidget {
  const ThermoloxChatButton({super.key});

  @override
  State<ThermoloxChatButton> createState() => _ThermoloxChatButtonState();
}

class _ThermoloxChatButtonState extends State<ThermoloxChatButton>
    with TickerProviderStateMixin {
  late final AnimationController _rotationCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    final tokens = ThermoloxTokens.light;

    // Drehring – läuft dauerhaft
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: tokens.ringRotationDuration,
    )..repeat();

    // Leichtes Pulsieren des Logos
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

  Future<void> _openChat() async {
    final height = MediaQuery.of(context).size.height * 0.85;
    final tokens = context.thermoloxTokens;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radiusSheet),
        ),
      ),
      builder: (ctx) {
        return SizedBox(height: height, child: const ThermoloxChatBot());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;

    final scale = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    return ScaleTransition(
      scale: scale,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _openChat,
          splashColor: theme.colorScheme.primary.withOpacity(0.18),
          highlightColor: Colors.transparent,
          child: SizedBox(
            width: 120, // größerer Hit-Bereich inkl. Glow
            height: 120,
            child: Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // 🔥 kräftiger, weicher Glow nach unten
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.65),
                      blurRadius: 30,
                      spreadRadius: 4,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 🌈 Rotierender Ring inkl. leichten Glow
                    RotationTransition(
                      turns: _rotationCtrl,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: tokens.rainbowRingGradient,
                          boxShadow: [
                            // leichter „Halo“, der mit dem Ring rotiert
                            BoxShadow(
                              color: tokens.rainbowRingHaloColor,
                              blurRadius: tokens.rainbowRingHaloBlur,
                              spreadRadius: tokens.rainbowRingHaloSpread,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Weißer innerer Kreis (Logo-Hintergrund)
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.scaffoldBackgroundColor,
                      ),
                    ),

                    // 🟣 Thermolox-Logo etwas größer (~1.2x)
                    SizedBox(
                      width: 60, // vorher 50
                      height: 60,
                      child: Image.asset(
                        'assets/icons/THERMOLOX_ICON.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
