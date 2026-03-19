import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'shell/everloxx_shell.dart';
import 'controllers/plan_controller.dart';
import 'models/cart_model.dart';
import 'models/projects_model.dart';
import 'services/auth_service.dart';
import 'services/consent_service.dart';
import 'services/credit_service.dart';
import 'services/deep_link_service.dart';
import 'services/legal_gate_service.dart';
import 'services/plan_service.dart';
import 'services/profile_service.dart';
import 'services/supabase_service.dart';
import 'services/design_token_service.dart';
import 'pages/legal_gate_page.dart';
import 'pages/email_verification_page.dart';
import 'pages/onboarding_page.dart';
import 'services/onboarding_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseService.initialize();
    await DesignTokenService.load();
    await DeepLinkService.initialize();
    try {
      await ConsentService.instance.load();
    } catch (_) {
      // If consent load fails, continue without blocking app start.
    }
    try {
      await LegalGateService.instance.load();
    } catch (_) {
      // If legal gate load fails, continue without blocking app start.
    }
  } on SupabaseConfigException catch (e) {
    runApp(
      _EverloxxErrorApp(
        message: e.message,
      ),
    );
    return;
  } catch (e) {
    runApp(
      _EverloxxErrorApp(
        message: 'Supabase initialization failed: $e',
      ),
    );
    return;
  }

  final authService = AuthService();
  final profileService = ProfileService();
  final planService = PlanService();
  final creditService = CreditService();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: authService),
        Provider.value(value: profileService),
        Provider.value(value: planService),
        Provider.value(value: creditService),
        ChangeNotifierProvider.value(value: ConsentService.instance),
        ChangeNotifierProvider.value(value: LegalGateService.instance),
        ChangeNotifierProvider(create: (_) => CartModel()),
        ChangeNotifierProvider(
          create: (_) => PlanController(planService, authService),
        ),
        ChangeNotifierProvider(create: (_) => ProjectsModel()),
      ],
      child: const EverloxxApp(),
    ),
  );
}

class EverloxxApp extends StatelessWidget {
  const EverloxxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: context.read<AuthService>().currentUserStream,
      builder: (context, snapshot) {
        final authService = context.read<AuthService>();
        final legalGate = context.watch<LegalGateService>();
        final user = snapshot.data;
        final needsVerification =
            user != null && !authService.isUserVerified(user);
        final home = !legalGate.isLoaded
            ? const _GateLoadingPage()
            : !legalGate.isAccepted
                ? const LegalGatePage()
                : needsVerification
                    ? const EmailVerificationPage()
                    : const _OnboardingGate();

        return MaterialApp(
          title: 'EVERLOXX',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          home: home,
        );
      },
    );
  }
}

class _EverloxxErrorApp extends StatelessWidget {
  final String message;

  const _EverloxxErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate();

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  bool _loading = true;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final completed = await OnboardingService.isCompleted();
    if (mounted) {
      setState(() {
        _completed = completed;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _GateLoadingPage();
    if (_completed) return const EverloxxShell();
    return OnboardingPage(
      onComplete: () => setState(() => _completed = true),
    );
  }
}

class _GateLoadingPage extends StatelessWidget {
  const _GateLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
