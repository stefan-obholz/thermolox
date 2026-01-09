import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/legal_gate_service.dart';
import '../theme/app_theme.dart';
import '../utils/thermolox_overlay.dart';

class LegalGatePage extends StatefulWidget {
  const LegalGatePage({super.key});

  @override
  State<LegalGatePage> createState() => _LegalGatePageState();
}

class _LegalGatePageState extends State<LegalGatePage> {
  bool _accepted = false;
  bool _busy = false;

  Future<void> _showLegalText(String title, String body) async {
    await ThermoloxOverlay.showAppDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Schliessen'),
          ),
        ],
      ),
    );
  }

  Future<void> _continue() async {
    if (!_accepted || _busy) return;
    setState(() => _busy = true);
    try {
      await context.read<LegalGateService>().accept();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;

    return ThermoloxScaffold(
      safeArea: true,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          0,
          tokens.gapLg,
          0,
          tokens.gapLg,
        ),
        children: [
          Center(
            child: Image.asset(
              'assets/logos/THERMOLOX_SYSTEMS.png',
              height: tokens.gapLg * 2,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: tokens.gapMd),
          Text(
            'Willkommen bei THERMOLOX',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tokens.gapSm),
          Text(
            'Um die App zu nutzen, stimme bitte unseren Bedingungen zu.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tokens.gapLg),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(tokens.gapMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _accepted,
                    onChanged: (value) =>
                        setState(() => _accepted = value ?? false),
                    title: Text(
                      'Ich stimme den AGB und der Datenschutzerklaerung zu',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  SizedBox(height: tokens.gapXs),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _showLegalText(
                          'AGB',
                          'Hier folgen die Allgemeinen Geschäftsbedingungen.',
                        ),
                        child: const Text('AGB ansehen'),
                      ),
                      TextButton(
                        onPressed: () => _showLegalText(
                          'Datenschutz',
                          'Hier folgt die Datenschutzerklaerung.',
                        ),
                        child: const Text('Datenschutz ansehen'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.gapMd),
          FilledButton(
            onPressed: _accepted ? _continue : null,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Weiter'),
          ),
        ],
      ),
    );
  }
}
