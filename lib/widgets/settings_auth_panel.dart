import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../controllers/plan_controller.dart';
import '../services/shopify_auth_service.dart';
import '../theme/app_theme.dart';

enum SettingsAuthMode { login, signup }

class SettingsAuthPanel extends StatefulWidget {
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final VoidCallback? onAuthenticated;
  final SettingsAuthMode initialMode;

  const SettingsAuthPanel({
    super.key,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    this.onAuthenticated,
    this.initialMode = SettingsAuthMode.signup,
  });

  @override
  State<SettingsAuthPanel> createState() => _SettingsAuthPanelState();
}

class _SettingsAuthPanelState extends State<SettingsAuthPanel> {
  bool _busy = false;
  String? _statusMessage;
  bool _statusIsError = false;
  StreamSubscription<bool>? _shopifyAuthSub;

  @override
  void initState() {
    super.initState();
    _shopifyAuthSub =
        ShopifyAuthService.instance.onAuthStateChanged.listen((loggedIn) {
      if (!mounted) return;
      if (loggedIn) {
        _onShopifyLoggedIn();
      }
    });
  }

  @override
  void dispose() {
    _shopifyAuthSub?.cancel();
    super.dispose();
  }

  void _setStatus(String message, {bool isError = false}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<void> _onShopifyLoggedIn() async {
    if (!mounted) return;
    await context.read<PlanController>().load(force: true);
    widget.onAuthenticated?.call();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _signInWithShopify() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      final success = await ShopifyAuthService.instance.login();
      if (!mounted) return;
      if (!success) {
        _setStatus('Anmeldung abgebrochen.', isError: true);
      }
      // If success, the stream listener in initState will handle navigation.
    } catch (e) {
      if (!mounted) return;
      _setStatus('Anmeldung fehlgeschlagen.', isError: true);
      if (kDebugMode) debugPrint('ShopifyAuth login error: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.everloxxTokens;
    final statusColor =
        _statusIsError ? theme.colorScheme.error : theme.colorScheme.primary;
    final padding = widget.padding ??
        EdgeInsets.fromLTRB(
          0,
          tokens.gapMd,
          0,
          tokens.gapLg,
        );

    return ListView(
      padding: padding,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      children: [
        Center(
          child: Text(
            'EVERLOXX',
            style: TextStyle(
              fontFamily: 'Times New Roman',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
        ),
        SizedBox(height: tokens.gapMd),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.all(tokens.gapMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Anmelden',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: tokens.gapSm),
                Text(
                  'Melde dich mit deinem Shopify-Konto an, '
                  'um Bestellungen aufzugeben, Projekte zu speichern '
                  'und dein Abonnement zu verwalten.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: tokens.gapLg),
                FilledButton.icon(
                  onPressed: _busy ? null : _signInWithShopify,
                  icon: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.storefront_rounded),
                  label: const Text('Mit Shopify anmelden'),
                ),
                if (_statusMessage != null) ...[
                  SizedBox(height: tokens.gapSm),
                  Text(
                    _statusMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
