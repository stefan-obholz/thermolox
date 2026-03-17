import 'package:flutter/material.dart';

bool isValidHex(String input) {
  var h = input.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length != 3 && h.length != 6) return false;
  return RegExp(r'^[0-9a-fA-F]+$').hasMatch(h);
}

String normalizeHex(String hex) {
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 3) {
    h = h.split('').map((c) => '$c$c').join();
  }
  if (h.length < 6) {
    h = h.padRight(6, '0');
  }
  if (h.length > 6) {
    h = h.substring(0, 6);
  }
  return '#${h.toUpperCase()}';
}

Color? colorFromHex(String hex) {
  if (!isValidHex(hex)) return null;
  final normalized = normalizeHex(hex);
  final raw = normalized.substring(1);
  final value = int.tryParse(raw, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

String hexFromColor(Color color) {
  final r = (color.r * 255).round();
  final g = (color.g * 255).round();
  final b = (color.b * 255).round();
  final value = (r << 16) | (g << 8) | b;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

int colorDistanceSquared(Color a, Color b) {
  final dr = (a.r * 255).round() - (b.r * 255).round();
  final dg = (a.g * 255).round() - (b.g * 255).round();
  final db = (a.b * 255).round() - (b.b * 255).round();
  return dr * dr + dg * dg + db * db;
}

Color? nearestColor(Color target, List<Color> palette) {
  if (palette.isEmpty) return null;
  var best = palette.first;
  var bestDist = colorDistanceSquared(target, best);
  for (final color in palette.skip(1)) {
    final dist = colorDistanceSquared(target, color);
    if (dist < bestDist) {
      best = color;
      bestDist = dist;
    }
  }
  return best;
}

String? nearestPaletteHex(String input, List<Color> palette) {
  final target = colorFromHex(input);
  if (target == null) return null;
  final best = nearestColor(target, palette);
  if (best == null) return null;
  return hexFromColor(best);
}
