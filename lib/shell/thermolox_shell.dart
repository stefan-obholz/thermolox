import 'package:flutter/material.dart';

import '../pages/settings_page.dart';
import '../pages/projects_page.dart';
import '../pages/products_page.dart';
import '../pages/home_page.dart';
import '../chat/chat_button.dart';

class ThermoloxShell extends StatefulWidget {
  final int initialIndex;

  const ThermoloxShell({super.key, this.initialIndex = 3});

  @override
  State<ThermoloxShell> createState() => _ThermoloxShellState();
}

class _ThermoloxShellState extends State<ThermoloxShell> {
  late int _currentIndex;
  final GlobalKey<HomePageState> _homePageKey = GlobalKey<HomePageState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pages = [
      const SettingsPage(),
      const ProjectsPage(),
      const ProductsPage(),
      HomePage(
        key: _homePageKey,
        onNavigateTab: (idx) => setState(() => _currentIndex = idx),
      ),
    ];
  }

  void _onNavTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    const Color footerColor = Color(0xFF242833);
    const Color iconBaseColor = Colors.white;

    // >>> EINSTELLUNGEN FÜR ABSTÄNDE <<<
    final double navTopPadding = 12; // Abstand Icons -> oberer Rand Footer
    const double gapOuter = 0; // Abstand Settings<->Projekte & Shop<->Home
    const double gapMiddle = 100; // Abstand Projekte<->Shop (unter Chat-Button)
    const double navItemWidth = 70; // Breite jedes Icon-Blocks (Icon+Text)

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),

      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        children: [
          // ---------- FOOTER ----------
          Container(
            height: 92,
            decoration: const BoxDecoration(
              color: footerColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
            ),
            // nur oben Padding -> vertikal einstellbar
            padding: EdgeInsets.only(top: navTopPadding),
            alignment: Alignment.topCenter, // 🔥 Row sitzt oben + Padding
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LINKS AUSSEN: SETTINGS
                SizedBox(
                  width: navItemWidth,
                  child: _NavIcon(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    index: 0,
                    currentIndex: _currentIndex,
                    onTap: _onNavTapped,
                    baseColor: iconBaseColor,
                  ),
                ),

                // Abstand 2 (links): Settings <-> Projekte
                const SizedBox(width: gapOuter),

                // MITTE LINKS: PROJEKTE
                SizedBox(
                  width: navItemWidth,
                  child: _NavIcon(
                    icon: Icons.layers_outlined,
                    label: 'Projekte',
                    index: 1,
                    currentIndex: _currentIndex,
                    onTap: _onNavTapped,
                    baseColor: iconBaseColor,
                  ),
                ),

                // Abstand 1: Projekte <-> Shop (unter Chat-Button)
                const SizedBox(width: gapMiddle),

                // MITTE RECHTS: SHOP
                SizedBox(
                  width: navItemWidth,
                  child: _NavIcon(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Shop',
                    index: 2,
                    currentIndex: _currentIndex,
                    onTap: _onNavTapped,
                    baseColor: iconBaseColor,
                  ),
                ),

                // Abstand 2 (rechts): Shop <-> Home
                const SizedBox(width: gapOuter),

                // RECHTS AUSSEN: HOME
                SizedBox(
                  width: navItemWidth,
                  child: _NavIcon(
                    icon: Icons.home_filled,
                    label: 'Home',
                    index: 3,
                    currentIndex: _currentIndex,
                    onTap: _onNavTapped,
                    baseColor: iconBaseColor,
                  ),
                ),
              ],
            ),
          ),

          // ---------- CHAT BUTTON (horizontal perfekt in der Mitte) ----------
          const Positioned(
            top: -40,
            left: 0,
            right: 0,
            child: Center(child: ThermoloxChatButton()),
          ),
        ],
      ),
    );
  }
}

/// Icon + Label im Footer
class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;
  final Color baseColor;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = index == currentIndex;

    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 26,
            color: isSelected ? Colors.white : baseColor.withOpacity(0.45),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected ? Colors.white : baseColor.withOpacity(0.60),
            ),
          ),
        ],
      ),
    );
  }
}
