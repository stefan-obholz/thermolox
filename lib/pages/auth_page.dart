import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/plan_controller.dart';
import '../theme/app_theme.dart';
import '../utils/thermolox_overlay.dart';
import '../widgets/thermolox_segmented_tabs.dart';

class AuthPage extends StatelessWidget {
  final int initialTabIndex;

  const AuthPage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex.clamp(0, 1),
      child: ThermoloxScaffold(
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
        body: Column(
          children: const [
            ThermoloxSegmentedTabs(
              labels: ['Login', 'Registrieren'],
              margin: EdgeInsets.zero,
              fill: true,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _AuthForm(mode: _AuthMode.login),
                  _AuthForm(mode: _AuthMode.signup),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AuthMode { login, signup }

class _AuthForm extends StatefulWidget {
  final _AuthMode mode;

  const _AuthForm({required this.mode});

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      ThermoloxOverlay.showSnack(
        context,
        'Bitte E-Mail und Passwort eingeben.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      if (widget.mode == _AuthMode.login) {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
        );
        if (response.session == null) {
          ThermoloxOverlay.showSnack(
            context,
            'Registrierung erfolgreich. Bitte E‑Mail bestätigen und dann einloggen.',
          );
          return;
        }
      }

      await context.read<PlanController>().load(force: true);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      final label = widget.mode == _AuthMode.login
          ? 'Anmeldung fehlgeschlagen'
          : 'Registrierung fehlgeschlagen';
      ThermoloxOverlay.showSnack(
        context,
        '$label: ${e.message}',
        isError: true,
      );
    } catch (e) {
      final label = widget.mode == _AuthMode.login
          ? 'Anmeldung fehlgeschlagen'
          : 'Registrierung fehlgeschlagen';
      ThermoloxOverlay.showSnack(
        context,
        label,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.thermoloxTokens;
    final isSignup = widget.mode == _AuthMode.signup;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        tokens.gapLg,
        0,
        tokens.gapLg,
      ),
      children: [
        Text(
          isSignup ? 'Konto erstellen' : 'Willkommen zurück',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        SizedBox(height: tokens.gapMd),
        TextFormField(
          controller: _emailCtrl,
          decoration: const InputDecoration(labelText: 'E-Mail'),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: tokens.gapSm),
        TextFormField(
          controller: _passwordCtrl,
          decoration: const InputDecoration(labelText: 'Passwort'),
          obscureText: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
        ),
        SizedBox(height: tokens.gapLg),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: Text(isSignup ? 'Registrieren' : 'Login'),
        ),
      ],
    );
  }
}
