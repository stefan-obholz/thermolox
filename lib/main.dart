import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'shell/thermolox_shell.dart';
import 'models/cart_model.dart';
import 'models/projects_model.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartModel()),
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
