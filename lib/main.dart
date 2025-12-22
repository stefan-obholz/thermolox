import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'theme/app_theme.dart';
import 'shell/thermolox_shell.dart';
import 'controllers/plan_controller.dart';
import 'models/cart_model.dart';
import 'models/projects_model.dart';
import 'services/plan_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabaseUrl = const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: kSupabaseUrl,
  );
  final supabaseAnonKey = const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: kSupabaseAnonKey,
  );

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(
      const _ThermoloxErrorApp(
        message:
            'Missing Supabase config. Provide SUPABASE_URL and SUPABASE_ANON_KEY.',
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    runApp(
      _ThermoloxErrorApp(
        message: 'Supabase initialization failed: $e',
      ),
    );
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartModel()),
        ChangeNotifierProvider(
          create: (_) =>
              PlanController(PlanService(Supabase.instance.client)),
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
    return MaterialApp(
      title: 'THERMOLOX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const ThermoloxShell(),
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
