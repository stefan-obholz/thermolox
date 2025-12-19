import 'package:flutter/material.dart';
import '../widgets/simple_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimplePage(
      title: 'THERMOLOX Home',
      description:
          'Hier kommt später deine Hero-Section, Vorteile, Slider & Einstieg in den Assistenten.',
    );
  }
}
