import 'package:flutter/material.dart';

class PaletteColor {
  final String hex;
  final String name;
  final String groupName;
  final int shadeIndex;
  final String? description;

  const PaletteColor({
    required this.hex,
    required this.name,
    required this.groupName,
    required this.shadeIndex,
    this.description,
  });

  factory PaletteColor.fromJson(Map<String, dynamic> json) => PaletteColor(
        hex: json['hex'] as String,
        name: json['name'] as String,
        groupName: json['group_name'] as String,
        shadeIndex: (json['shade_index'] as num).toInt(),
        description: json['description'] as String?,
      );

  Color get color {
    final s = hex.replaceAll('#', '');
    return Color(int.parse('FF$s', radix: 16));
  }

  String get label => '$groupName – Farbton $shadeIndex';
}

class PaletteGroup {
  final String name;
  final List<PaletteColor> shades;

  const PaletteGroup({required this.name, required this.shades});
}
