import 'package:flutter/material.dart';

List<Color> _materialShades(MaterialColor color) => [
      color.shade50,
      color.shade100,
      color.shade200,
      color.shade300,
      color.shade400,
      color.shade500,
      color.shade600,
      color.shade700,
      color.shade800,
      color.shade900,
    ];

final List<Color> thermoloxPalette = [
  ..._materialShades(Colors.red),
  ..._materialShades(Colors.pink),
  ..._materialShades(Colors.purple),
  ..._materialShades(Colors.indigo),
  ..._materialShades(Colors.blue),
  ..._materialShades(Colors.cyan),
  ..._materialShades(Colors.teal),
  ..._materialShades(Colors.green),
  ..._materialShades(Colors.lime),
  ..._materialShades(Colors.orange),
];
