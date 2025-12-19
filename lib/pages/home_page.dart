import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/cart_icon_button.dart';
import '../theme/app_theme.dart';
import 'products_page.dart';

class HomePage extends StatefulWidget {
  final void Function(int)? onNavigateTab;

  const HomePage({super.key, this.onNavigateTab});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final GlobalKey<ThermoloxShowcaseState> _showcaseKey =
      GlobalKey<ThermoloxShowcaseState>();
  final GlobalKey<ThermoloxIconStripState> _iconStripKey =
      GlobalKey<ThermoloxIconStripState>();
  bool _hasPlayed = false;

  /// Sammelpunkt für alle Home-Abschnitte.
  /// Neue Blöcke können einfach angehängt werden.
  List<Widget> _buildSections(BuildContext context) {
    final tokens = context.thermoloxTokens;
    final tightPadding =
        EdgeInsets.symmetric(horizontal: tokens.screenPaddingSm);
    final textPadding =
        EdgeInsets.symmetric(horizontal: tokens.screenPadding);

    return [
      Padding(
        padding: tightPadding,
        child: ThermoloxShowcase(
          key: _showcaseKey,
          onCompleted: _playIconStrip,
        ),
      ),
      const SizedBox(height: 4), // tighter spacing
      Padding(
        padding: textPadding,
        child: ThermoloxIconStrip(key: _iconStripKey),
      ),
      Padding(
        padding: tightPadding,
        child: const ThermoloxBeforeAfter(),
      ),
      const SizedBox(height: 20),
      const ThermoloxImpactText(),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => playAnimation());
  }

  void playAnimation() {
    if (_hasPlayed) return;
    _hasPlayed = true;
    _showcaseKey.currentState?.play();
  }

  void _playIconStrip() {
    _iconStripKey.currentState?.play();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    final sections = _buildSections(context);

    return ThermoloxScaffold(
      safeArea: true,
      padding: EdgeInsets.zero,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'THERMOLOX',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.0,
          ),
        ),
        actions: const [CartIconButton()],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          0,
          tokens.gapMd,
          0,
          tokens.gapLg,
        ),
        itemCount: sections.length,
        itemBuilder: (context, index) => sections[index],
        separatorBuilder: (_, __) => const SizedBox(height: 16),
      ),
    );
  }
}

class ThermoloxShowcase extends StatefulWidget {
  final VoidCallback? onCompleted;

  const ThermoloxShowcase({super.key, this.onCompleted});

  @override
  ThermoloxShowcaseState createState() => ThermoloxShowcaseState();
}

class ThermoloxShowcaseState extends State<ThermoloxShowcase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_hasCompleted) {
        _hasCompleted = true;
        widget.onCompleted?.call();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => play());
  }

  void play() {
    _controller.forward(from: 0);
    _hasCompleted = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double rightImageHeight = 220;
    const double leftImageHeight = rightImageHeight / 1.2; // ~1.2x kleiner
    const double gap = 32;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: double.infinity,
          height: rightImageHeight + 2,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: leftImageHeight,
                          child: Image.asset(
                            'assets/images/THERMOSEAL.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(width: gap),
                        SizedBox(
                          height: rightImageHeight,
                          child: Image.asset(
                            'assets/images/THERMOCOAT.png',
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
      },
    );
  }
}

class ThermoloxIconStrip extends StatefulWidget {
  const ThermoloxIconStrip({super.key});

  @override
  ThermoloxIconStripState createState() => ThermoloxIconStripState();
}

class ThermoloxIconStripState extends State<ThermoloxIconStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  Timer? _typingTimer;
  String _displayText = '';
  int _typingIndex = 0;
  static const String _fullText =
      '„Das Thermolox-System ist das Balkonkraftwerk für Wände\n- nur effektiver.“';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  void play() {
    _controller.forward(from: 0);
    _startTyping();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTyping() {
    _typingTimer?.cancel();
    _displayText = '';
    _typingIndex = 0;
    const step = Duration(milliseconds: 30);
    _typingTimer = Timer.periodic(step, (timer) {
      if (_typingIndex >= _fullText.length) {
        timer.cancel();
        return;
      }
      setState(() {
        _typingIndex++;
        _displayText = _fullText.substring(0, _typingIndex);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double targetWidth = constraints.maxWidth * 0.85;
        return Center(
          child: Transform.translate(
            offset: const Offset(0, -36),
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: targetWidth,
                    child: Image.asset(
                      'assets/images/THERMOLOX_3x_ICONs.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: targetWidth,
                    height: 64, // reserve space to avoid layout shift
                    child: Text(
                      _displayText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ThermoloxBeforeAfter extends StatefulWidget {
  const ThermoloxBeforeAfter({super.key});

  @override
  State<ThermoloxBeforeAfter> createState() => _ThermoloxBeforeAfterState();
}

class _ThermoloxBeforeAfterState extends State<ThermoloxBeforeAfter> {
  double _value = 50.0;

  void _onChanged(double newValue) {
    setState(() => _value = newValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double percent = (_value / 100).clamp(0.0, 1.0);
        final double handleX = width * percent;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'So sieht echte Energieeinsparung aus',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.0,
              ),
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _BeforeAfterSlider(
                percent: percent,
                handleX: handleX,
                onChanged: _onChanged,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BeforeAfterSlider extends StatelessWidget {
  final double percent;
  final double handleX;
  final ValueChanged<double> onChanged;

  const _BeforeAfterSlider({
    required this.percent,
    required this.handleX,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double clampedX = handleX.clamp(0, width);
        const double buttonSize = 40;
        const double buttonGap = 10;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/HAUS_SCHIEBER_COOL.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: ClipPath(
                clipper: _RightClipper(percent: percent),
                child: Image.asset(
                  'assets/images/HAUS_SCHIEBER_HOT.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CenterLinePainter(x: clampedX, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              left: (clampedX - buttonGap - buttonSize).clamp(0.0, width - buttonSize),
              top: (constraints.maxHeight - buttonSize) / 2,
              child: _ArrowButton(icon: Icons.chevron_left, size: buttonSize),
            ),
            Positioned(
              left: (clampedX + buttonGap).clamp(0.0, width - buttonSize),
              top: (constraints.maxHeight - buttonSize) / 2,
              child: _ArrowButton(icon: Icons.chevron_right, size: buttonSize),
            ),
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
                  max: 100,
                  value: percent * 100,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
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
    final Paint linePaint = Paint()
      ..color = color
      ..strokeWidth = 2;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
  }

  @override
  bool shouldRepaint(covariant _CenterLinePainter oldDelegate) =>
      oldDelegate.x != x || oldDelegate.color != color;
}

class _RightClipper extends CustomClipper<Path> {
  final double percent;

  _RightClipper({required double percent})
      : percent = percent.clamp(0.0, 1.0);

  @override
  Path getClip(Size size) {
    final double w = size.width * percent;
    return Path()..addRect(Rect.fromLTWH(0, 0, w, size.height));
  }

  @override
  bool shouldReclip(covariant _RightClipper oldClipper) =>
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

class ThermoloxImpactText extends StatelessWidget {
  const ThermoloxImpactText({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    const bulletSpacing = SizedBox(height: 10);
    const double bodySize = 15;

    Widget bullet(String text) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✅ ', style: TextStyle(fontSize: 18)),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.35,
                fontSize: bodySize,
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.screenPadding,
        4,
        tokens.screenPadding,
        tokens.gapLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unser Wärmebild-Vergleich zeigt eindrucksvoll die Wirkung des '
            'THERMOLOX-Systems: Links ein unbehandeltes Gebäude – rechts ein Haus, '
            'das mit THERMO-COAT gestrichen und mit THERMO-SEAL abgedichtet wurde.',
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.35,
              fontSize: bodySize,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '💡 Weniger Wärmeverlust bedeutet:\n'
            'Weniger Heizkosten. Mehr Komfort. Besser fürs Klima.',
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.4,
              fontWeight: FontWeight.w700,
              fontSize: bodySize,
            ),
          ),
          const SizedBox(height: 18),
          bullet('Ideal für Altbau & unsanierte Gebäude'),
          bulletSpacing,
          bullet('Spart bis zu 42% Heiz- und Kühlkosten'),
          bulletSpacing,
          bullet('Sofortige Wirkung nach der Anwendung'),
          bulletSpacing,
          bullet('Ohne Handwerker oder Umbau'),
          const SizedBox(height: 22),
          Text(
            'Energie sparen war noch nie so einfach.',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.35,
              fontSize: bodySize,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Setze auf das THERMOLOX-System – die nachhaltige, '
            'rückbaufreie und günstige Alternative zur klassischen Sanierung.',
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.35,
              fontSize: bodySize,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final onTab = context.findAncestorStateOfType<HomePageState>()?.widget.onNavigateTab;
                if (onTab != null) {
                  onTab(2);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProductsPage()),
                  );
                }
              },
              child: const Text('Jetzt entdecken'),
            ),
          ),
        ],
      ),
    );
  }
}
