import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // ➜ AppBar OHNE Warenkorb
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Einstellungen',
          style: TextStyle(
            fontSize: 34, // ✅ identisch zur Referenz
            fontWeight: FontWeight.w800,
            letterSpacing: 0.0,
          ),
        ),
        actions: const [], // ❌ kein Cart hier
      ),

      backgroundColor: theme.scaffoldBackgroundColor,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hier kommen später App-Einstellungen, Datenschutz,\n'
                'Rechtliches & Account-Optionen rein.',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
