import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'shell/thermolox_shell.dart';
import 'controllers/plan_controller.dart';
import 'models/cart_model.dart';
import 'models/projects_model.dart';
import 'services/auth_service.dart';
import 'services/credit_service.dart';
import 'services/deep_link_service.dart';
import 'services/plan_service.dart';
import 'services/profile_service.dart';
import 'services/supabase_service.dart';
import 'pages/email_verification_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseService.initialize();
    await DeepLinkService.initialize();
  } on SupabaseConfigException catch (e) {
    runApp(
      _ThermoloxErrorApp(
        message: e.message,
      ),
    );
    return;
  } catch (e) {
    runApp(
      _ThermoloxErrorApp(
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
        ChangeNotifierProvider(create: (_) => CartModel()),
        ChangeNotifierProvider(
          create: (_) => PlanController(planService, authService),
        ),
        ChangeNotifierProvider(create: (_) => ProjectsModel()),
      ],
      child: const ThermoloxApp(),
    ),
  );
}

class ThermoloxApp extends StatelessWidget {
  const ThermoloxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: context.read<AuthService>().currentUserStream,
      builder: (context, snapshot) {
        final authService = context.read<AuthService>();
        final user = snapshot.data;
        final needsVerification =
            user != null && !authService.isUserVerified(user);

        return MaterialApp(
          title: 'THERMOLOX',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          home: needsVerification
              ? const EmailVerificationPage()
              : const ThermoloxShell(),
        );
      },
    );
  }
}

class _ThermoloxErrorApp extends StatelessWidget {
  final String message;

  const _ThermoloxErrorApp({required this.message});

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
