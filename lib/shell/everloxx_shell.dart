import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pages/settings_page.dart';
import '../pages/projects_page.dart';
import '../pages/products_page.dart';
import '../pages/home_page.dart';
import '../chat/chat_button.dart';
import '../controllers/plan_controller.dart';

class EverloxxShell extends StatefulWidget {
  final int initialIndex;

  const EverloxxShell({super.key, this.initialIndex = 3});

  @override
  State<EverloxxShell> createState() => _EverloxxShellState();
}

class _EverloxxShellState extends State<EverloxxShell> {
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

  Future<void> _onNavTapped(int index) async {
    // Projekte (index 1) is premium
    if (index == 1) {
      final planController = context.read<PlanController>();
      if (!planController.isPro) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projekte ist ein Premium-Feature.')),
        );
        return;
      }
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final Color footerColor = AppTheme.primary;
    const Color iconBaseColor = Colors.white;
    final canAccessProjects =
        context.watch<PlanController>().hasProjectsAccess;

    if (!canAccessProjects && _currentIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentIndex = 3);
        }
      });
    }

    // >>> EINSTELLUNGEN FÜR ABSTÄNDE <<<
    final double navTopPadding = 12; // Abstand Icons -> oberer Rand Footer
    const double gapOuter = 0; // Abstand Settings<->Projekte & Shop<->Home
    const double gapMiddle = 100; // Abstand Projekte<->Shop (unter Chat-Button)
    const double navItemWidth = 70; // Breite jedes Icon-Blocks (Icon+Text)

    return PopScope(
      canPop: _currentIndex == 3,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _currentIndex = 3);
        }
      },
      child: Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),

      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        children: [
          // ---------- FOOTER ----------
          Container(
            height: 92,
            decoration: BoxDecoration(
              color: footerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
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
                    enabled: true,
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
                    enabled: canAccessProjects,
                    allowTapWhenDisabled: true,
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
                    enabled: true,
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
                    enabled: true,
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
            child: Center(child: EverloxxChatButton()),
          ),
        ],
      ),
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
  final bool enabled;
  final bool allowTapWhenDisabled;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.baseColor,
    required this.enabled,
    this.allowTapWhenDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = index == currentIndex;
    final effectiveEnabled = enabled;
    final tapEnabled = enabled || allowTapWhenDisabled;
    final inactiveColor =
        effectiveEnabled ? baseColor.withValues(alpha: 0.45) : baseColor.withValues(alpha: 0.2);
    final inactiveLabel =
        effectiveEnabled ? baseColor.withValues(alpha: 0.60) : baseColor.withValues(alpha: 0.3);

    return InkWell(
      onTap: tapEnabled ? () => onTap(index) : null,
      borderRadius: BorderRadius.circular(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 26,
            color: isSelected ? Colors.white : inactiveColor,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected ? Colors.white : inactiveLabel,
            ),
          ),
        ],
      ),
    );
  }
}
