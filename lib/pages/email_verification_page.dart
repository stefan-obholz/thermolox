import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/deep_link_service.dart';
import '../theme/app_theme.dart';
import '../utils/thermolox_overlay.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isLoading = false;

  Future<void> _resend() async {
    final auth = context.read<AuthService>();
    final email = auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      ThermoloxOverlay.showSnack(
        context,
        'Keine E-Mail gefunden.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await auth.resendSignupEmail(email: email);
      ThermoloxOverlay.showSnack(
        context,
        'E-Mail wurde erneut versendet.',
      );
    } catch (e) {
      ThermoloxOverlay.showSnack(
        context,
        'E-Mail konnte nicht versendet werden.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthService>();
    setState(() => _isLoading = true);
    try {
      await auth.refreshSession();
      ThermoloxOverlay.showSnack(
        context,
        'Status aktualisiert.',
      );
    } catch (e) {
      ThermoloxOverlay.showSnack(
        context,
        'Aktualisierung fehlgeschlagen.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthService>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.thermoloxTokens;
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final email = user?.email ?? '';
    final isVerified = auth.isUserVerified(user);

    return ThermoloxScaffold(
      safeArea: true,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('E-Mail bestätigen'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          0,
          tokens.gapLg,
          0,
          tokens.gapLg,
        ),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              ),
              child: Icon(
                Icons.mark_email_read_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(height: tokens.gapMd),
          Text(
            'Bitte bestätige deine E-Mail-Adresse',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tokens.gapSm),
          Text(
            'Wir haben dir einen Bestätigungslink gesendet. Danach kannst du die App voll nutzen.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (email.isNotEmpty) ...[
            SizedBox(height: tokens.gapMd),
            Center(
              child: Text(
                email,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
          SizedBox(height: tokens.gapLg),
          Container(
            padding: EdgeInsets.all(tokens.gapMd),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nächste Schritte',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                SizedBox(height: tokens.gapSm),
                Text(
                  'E-Mail öffnen und Link bestätigen.\n'
                  'Danach hier auf "Ich habe bestätigt" tippen.\n'
                  'Falls nichts ankommt, Spam-Ordner prüfen.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.gapLg),
          ElevatedButton(
            onPressed: _isLoading ? null : _refresh,
            child: Text(isVerified ? 'Bestätigt' : 'Ich habe bestätigt'),
          ),
          SizedBox(height: tokens.gapSm),
          OutlinedButton(
            onPressed: _isLoading ? null : _resend,
            child: const Text('E-Mail erneut senden'),
          ),
          SizedBox(height: tokens.gapSm),
          TextButton(
            onPressed: _isLoading ? null : _signOut,
            child: const Text('Abmelden'),
          ),
          if (kDebugMode) ...[
            SizedBox(height: tokens.gapLg),
            _DebugPanel(
              email: email,
              isVerified: isVerified,
            ),
          ],
        ],
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  final String email;
  final bool isVerified;

  const _DebugPanel({
    required this.email,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.thermoloxTokens;
    final lastLink = DeepLinkService.lastDeepLink ?? 'none';
    final lastSource = DeepLinkService.lastDeepLinkSource ?? 'n/a';
    final lastAt = DeepLinkService.lastDeepLinkAt?.toIso8601String() ?? 'n/a';

    return Container(
      padding: EdgeInsets.all(tokens.gapMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debug',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          SizedBox(height: tokens.gapSm),
          Text('email: $email'),
          Text('verified: $isVerified'),
          SizedBox(height: tokens.gapSm),
          const Text('last deep link:'),
          SelectableText(lastLink),
          SizedBox(height: tokens.gapXs),
          Text('source: $lastSource'),
          Text('at: $lastAt'),
        ],
      ),
    );
  }
}
