import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_auth_panel.dart';

class AuthPage extends StatelessWidget {
  final int initialTabIndex;

  const AuthPage({
    super.key,
    this.initialTabIndex = 1,
  });

  @override
  Widget build(BuildContext context) {
    final initialMode = initialTabIndex == 1
        ? SettingsAuthMode.signup
        : SettingsAuthMode.login;

    return ThermoloxScaffold(
      safeArea: true,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Account',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.0,
          ),
        ),
      ),
      body: SettingsAuthPanel(
        initialMode: initialMode,
        onAuthenticated: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}
