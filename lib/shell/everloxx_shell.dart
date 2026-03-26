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
            // Pages
            IndexedStack(index: _currentIndex, children: _pages),

            // Bottom nav bar + center button
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Center ring button (overlaps above the bar)
                  GestureDetector(
                    onTap: () => setState(() => _currentIndex = 2),
                    child: ScaleTransition(
                      scale: _pulseAnim,
                      child: SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Gold fill
                            Container(
                              width: 120,
                              height: 120,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFefd2a7),
                              ),
                            ),
                            // Ring on top
                            Image.asset(
                              'assets/images/EVERLOXX_ICON.png',
                              width: 140,
                              height: 140,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Nav bar
                  Container(
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
                ],
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
