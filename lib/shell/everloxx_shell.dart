import 'dart:ui';

import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../pages/products_page.dart';
import '../pages/projects_page.dart';
import '../pages/settings_page.dart';
import '../chat/chat_bot.dart';

class EverloxxShell extends StatefulWidget {
  final int initialIndex;

  const EverloxxShell({super.key, this.initialIndex = 4});

  @override
  State<EverloxxShell> createState() => _EverloxxShellState();
}

class _EverloxxShellState extends State<EverloxxShell>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pages = const [
      SettingsPage(),    // 0 — Konto
      ProjectsPage(),    // 1 — Projekte
      EverloxxChatBot(), // 2 — Chatbot
      ProductsPage(),    // 3 — Produkte
      HomePage(),        // 4 — Home
    ];

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: _currentIndex == 4,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _currentIndex = 4);
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Pages – inflate bottom viewPadding so Scaffold/ListView
            // automatically keeps content above the custom nav bar + ring.
            MediaQuery(
              data: MediaQuery.of(context).copyWith(
                viewPadding: MediaQuery.of(context).viewPadding.copyWith(
                  bottom: bottomPad + 56 + 70,
                ),
              ),
              child: IndexedStack(index: _currentIndex, children: _pages),
            ),

            // Nav bar with circular cutout
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipPath(
                clipper: _NavBarClipper(
                  ringDiameter: 90,
                  barHeight: 56 + bottomPad,
                ),
                child: Container(
                  color: const Color(0xFF1A1614),
                  padding: EdgeInsets.only(bottom: bottomPad),
                  child: SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        _navItem(Icons.person_outline, Icons.person, 'Konto', 0),
                        _navItem(Icons.folder_outlined, Icons.folder, 'Projekte', 1),
                        const Spacer(),
                        _navItem(Icons.palette_outlined, Icons.palette, 'Produkte', 3),
                        _navItem(Icons.home_outlined, Icons.home, 'Home', 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Frosted glass circle in the cutout
            Positioned(
              bottom: bottomPad + 56 - 45, // center of cutout
              left: 0,
              right: 0,
              child: Center(
                child: ClipOval(
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1614).withValues(alpha: 0.12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.08),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Center ring button – centered on top edge of nav bar
            Positioned(
              bottom: bottomPad + 56 - 70, // nav bar top minus half ring height
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = 2),
                  child: ScaleTransition(
                    scale: _pulseAnim,
                    child: Image.asset(
                      'assets/images/EVERLOXX_ICON.png',
                      width: 140,
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, IconData activeIcon, String label, int index) {
    final isActive = _currentIndex == index;
    final color = isActive ? Colors.white : Colors.white.withValues(alpha: 0.4);
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBarClipper extends CustomClipper<Path> {
  final double ringDiameter;
  final double barHeight;

  _NavBarClipper({required this.ringDiameter, required this.barHeight});

  @override
  Path getClip(Size size) {
    final path = Path();
    final centerX = size.width / 2;
    final radius = ringDiameter / 2;

    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    path.addOval(Rect.fromCircle(center: Offset(centerX, 0), radius: radius));
    path.fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(covariant _NavBarClipper oldClipper) =>
      ringDiameter != oldClipper.ringDiameter || barHeight != oldClipper.barHeight;
}
