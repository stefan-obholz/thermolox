import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import 'package:url_launcher/url_launcher.dart';

import '../controllers/plan_controller.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/consent_service.dart';
import '../services/legal_gate_service.dart';
import '../services/profile_service.dart';
import '../services/supabase_service.dart';
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
  static const int _passwordMinLength = 8;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late bool _isLogin;
  bool _busy = false;
  bool _emailSent = false;
  bool _acceptLegal = false;
  bool _marketingAccepted = false;
  bool _analyticsAccepted = false;
  bool _aiAccepted = false;
  String? _statusMessage;
  bool _statusIsError = false;
  String? _debugInfo;
  bool _oauthInFlight = false;
  StreamSubscription<AuthState>? _authSub;

  bool get _showDebugDetails => kDebugMode;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialMode == SettingsAuthMode.login;
    _authSub = SupabaseService.client.auth.onAuthStateChange.listen((data) {
      if (!_oauthInFlight) return;
      final user = data.session?.user;
      if (user == null) return;
      _oauthInFlight = false;
      _handleOAuthUser(user);
    });
  }

  @override
  void didUpdateWidget(covariant SettingsAuthPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMode != widget.initialMode) {
      _isLogin = widget.initialMode == SettingsAuthMode.login;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setStatus(String message, {bool isError = false}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  void _setDebugInfo(String info) {
    _debugInfo = info;
    if (_showDebugDetails && mounted) {
      setState(() {});
    }
  }

  Future<void> _handleOAuthUser(User user) async {
    if (!mounted) return;
    final profileService = context.read<ProfileService>();
    final authService = context.read<AuthService>();
    final consentService = context.read<ConsentService>();
    final legalGate = context.read<LegalGateService>();
    final locale = Localizations.localeOf(context).toLanguageTag();

    try {
      await profileService.seedProfileFromAuth(
        user: user,
        locale: locale,
      );
    } catch (_) {
      // ignore optional profile seeding errors
    }

    UserProfile? profile;
    try {
      profile = await profileService.getProfile(user.id);
    } catch (_) {
      profile = null;
    }

    final needsConsents = !authService.isUserVerified(user) ||
        profileService.needsConsents(profile);
    if (needsConsents) {
      if (!legalGate.isAccepted) {
        final accepted = await _showConsentSheet();
        if (!accepted) {
          await SupabaseService.client.auth.signOut();
          if (!mounted) return;
          _setStatus(
            'Bitte AGB und Datenschutzerklärung akzeptieren.',
            isError: true,
          );
          return;
        }
      }
      try {
        await profileService.ensureConsents(
          userId: user.id,
          termsAccepted: legalGate.isAccepted || _acceptLegal,
          privacyAccepted: legalGate.isAccepted || _acceptLegal,
          marketingAccepted: _marketingAccepted,
          locale: locale,
          forceIfMissing: true,
          source: 'google',
        );
        await legalGate.syncToServerIfNeeded();
        if (_analyticsAccepted) {
          await consentService.setAnalyticsAllowed(true);
        }
        if (_aiAccepted) {
          await consentService.setAiAllowed(true);
        }
      } catch (_) {
        // ignore consent write errors; UI will still be logged in
      }
    }

    await context.read<PlanController>().load(force: true);
    widget.onAuthenticated?.call();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _showConsentSheet() async {
    if (!mounted) return false;
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    bool accepted = _acceptLegal;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radiusSheet),
        ),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.screenPaddingSm,
          tokens.gapMd,
          tokens.screenPaddingSm,
          MediaQuery.of(context).viewInsets.bottom + tokens.gapLg,
        ),
        child: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bitte bestätigen',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.gapSm),
              Text(
                'Damit wir dein Konto aktivieren können, brauchen wir deine Zustimmung.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.gapMd),
              CheckboxListTile(
                value: accepted,
                onChanged: (value) => setState(() {
                  accepted = value ?? false;
                }),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Ich stimme den AGB und der Datenschutzerklärung zu',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(height: tokens.gapSm),
              FilledButton(
                onPressed: accepted ? () => Navigator.of(context).pop(true) : null,
                child: const Text('Weiter'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Abbrechen'),
              ),
            ],
          ),
        ),
      ),
    );
    _acceptLegal = accepted;
    return result ?? false;
  }

  bool _isStrongPassword(String value) {
    return value.length >= _passwordMinLength;
  }

  bool _isValidEmail(String value) {
    final email = value.trim().toLowerCase();
    return email.contains('@') && email.contains('.');
  }

  void _switchMode(bool login) {
    final legalGate = context.read<LegalGateService>();
    setState(() {
      _isLogin = login;
      _emailSent = false;
      _statusMessage = null;
      _statusIsError = false;
      _acceptLegal = legalGate.isAccepted;
      _marketingAccepted = false;
      _analyticsAccepted = false;
      _aiAccepted = false;
      _debugInfo = null;
    });
  }

  Future<void> _submitEmailAuth() async {
    if (_busy) return;
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final legalGate = context.read<LegalGateService>();
    final legalAccepted = legalGate.isAccepted || _acceptLegal;

    if (!_isValidEmail(email)) {
      _setStatus('Bitte eine gültige E-Mail eingeben.', isError: true);
      return;
    }
    if (password.trim().isEmpty) {
      _setStatus('Bitte ein Passwort eingeben.', isError: true);
      return;
    }
    if (!_isLogin && !_isStrongPassword(password)) {
      _setStatus('Passwort muss mindestens 8 Zeichen lang sein.', isError: true);
      return;
    }
    if (!_isLogin && !legalAccepted) {
      _setStatus(
        'Bitte AGB und Datenschutzerklärung akzeptieren.',
        isError: true,
      );
      return;
    }

    setState(() {
      _busy = true;
      _statusMessage = null;
      _statusIsError = false;
      _debugInfo = null;
    });

    try {
      final authService = context.read<AuthService>();
      final profileService = context.read<ProfileService>();
      final consentService = context.read<ConsentService>();
      final locale = Localizations.localeOf(context).toLanguageTag();

      if (_isLogin) {
        final response = await authService.signIn(
          email: email,
          password: password,
        );
        _setDebugInfo(
          'login: user=${response.user != null} session=${response.session != null}',
        );
      } else {
        final response = await authService.signUp(
          email: email,
          password: password,
        );
        _setDebugInfo(
          'signup: user=${response.user != null} session=${response.session != null}',
        );

        final user = response.user ?? authService.currentUser;
        if (user != null) {
          await profileService.ensureConsents(
            userId: user.id,
            termsAccepted: legalAccepted,
            privacyAccepted: legalAccepted,
            marketingAccepted: _marketingAccepted,
            locale: locale,
          );
          await legalGate.syncToServerIfNeeded();
          if (_analyticsAccepted) {
            await consentService.setAnalyticsAllowed(true);
          }
          if (_aiAccepted) {
            await consentService.setAiAllowed(true);
          }
        }

        if (response.session == null) {
          setState(() => _emailSent = true);
          _setStatus(
            'E-Mail wurde versendet. Bitte bestätigen.',
            isError: false,
          );
          return;
        }
      }

      await context.read<PlanController>().load(force: true);
      widget.onAuthenticated?.call();
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      _setStatus(
        '${_isLogin ? 'Anmeldung' : 'Registrierung'} fehlgeschlagen: ${e.message}',
        isError: true,
      );
    } catch (e) {
      _setStatus(
        '${_isLogin ? 'Anmeldung' : 'Registrierung'} fehlgeschlagen.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _busy = true);
    try {
      final authService = context.read<AuthService>();
      await authService.resendSignupEmail(email: email);
      if (!mounted) return;
      _setStatus('E-Mail erneut gesendet.');
    } catch (_) {
      if (!mounted) return;
      _setStatus('E-Mail konnte nicht gesendet werden.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_busy) return;
    final email = _emailController.text.trim().toLowerCase();
    if (!_isValidEmail(email)) {
      _setStatus('Bitte eine gültige E-Mail eingeben.', isError: true);
      return;
    }
    setState(() {
      _busy = true;
      _statusMessage = null;
      _statusIsError = false;
    });
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(
        email,
        redirectTo: SupabaseService.redirectUrl,
      );
      if (!mounted) return;
      _setStatus('Reset-Link wurde gesendet.');
    } catch (_) {
      if (!mounted) return;
      _setStatus('Passwort-Reset fehlgeschlagen.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_busy || _oauthInFlight) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
      _statusIsError = false;
      _oauthInFlight = true;
    });
    try {
      await SupabaseService.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: SupabaseService.redirectUrl,
        authScreenLaunchMode: LaunchMode.inAppBrowserView,
      );
    } catch (_) {
      _oauthInFlight = false;
      if (!mounted) return;
      _setStatus('Google Login fehlgeschlagen.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    final legalGate = context.watch<LegalGateService>();
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
          child: Image.asset(
            'assets/logos/THERMOLOX_SYSTEMS.png',
            height: tokens.gapLg * 2,
            fit: BoxFit.contain,
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
              Row(
                children: [
                  Expanded(
                    child: _isLogin
                        ? OutlinedButton(
                            onPressed: _busy ? null : () => _switchMode(false),
                            child: const Text('Registrieren'),
                          )
                        : FilledButton(
                            onPressed: _busy ? null : () => _switchMode(false),
                            child: const Text('Registrieren'),
                          ),
                  ),
                  SizedBox(width: tokens.gapSm),
                  Expanded(
                    child: _isLogin
                        ? FilledButton(
                            onPressed: _busy ? null : () => _switchMode(true),
                            child: const Text('Login'),
                          )
                        : OutlinedButton(
                            onPressed: _busy ? null : () => _switchMode(true),
                            child: const Text('Login'),
                          ),
                  ),
                ],
              ),
              SizedBox(height: tokens.gapMd),
              TextField(
                controller: _emailController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-Mail'),
              ),
              SizedBox(height: tokens.gapSm),
              TextField(
                controller: _passwordController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Passwort'),
                onSubmitted: (_) => _submitEmailAuth(),
              ),
              if (_isLogin) ...[
                SizedBox(height: tokens.gapXs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _sendPasswordReset,
                    child: const Text('Passwort vergessen?'),
                  ),
                ),
              ],
              if (!_isLogin && !legalGate.isAccepted) ...[
                SizedBox(height: tokens.gapSm),
                CheckboxListTile(
                  value: _acceptLegal,
                  onChanged: _busy
                      ? null
                      : (value) =>
                          setState(() => _acceptLegal = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'Ich stimme den AGB und der Datenschutzerklärung zu',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
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
              SizedBox(height: tokens.gapSm),
              FilledButton(
                onPressed: _busy ? null : _submitEmailAuth,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isLogin ? 'Login' : 'Registrieren'),
              ),
              if (_emailSent) ...[
                SizedBox(height: tokens.gapXs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _resendVerificationEmail,
                    child: const Text('E-Mail erneut senden'),
                  ),
                ),
              ],
              SizedBox(height: tokens.gapMd),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: theme.colorScheme.onSurface.withOpacity(0.2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: tokens.gapSm),
                    child: Text(
                      'oder',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: theme.colorScheme.onSurface.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.gapMd),
              OutlinedButton.icon(
                onPressed: _busy ? null : _signInWithGoogle,
                icon: Image.asset(
                  'assets/icons/google_icon.png',
                  width: tokens.gapMd * 1.5,
                  height: tokens.gapMd * 1.5,
                ),
                label: const Text('Mit Google fortfahren'),
              ),
              if (_showDebugDetails && _debugInfo != null) ...[
                SizedBox(height: tokens.gapSm),
                Text(
                  _debugInfo!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
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
