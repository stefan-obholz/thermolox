import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/palette_service.dart';
import 'color_utils.dart';

Future<String?> scanNearestPaletteHexFromImagePath(
  String path, {
  int targetSize = 64,
}) async {
  try {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetSize,
      targetHeight: targetSize,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (data == null) return null;

    final rgba = data.buffer.asUint8List();
    var r = 0;
    var g = 0;
    var b = 0;
    var count = 0;

    for (var i = 0; i + 3 < rgba.length; i += 4) {
      final alpha = rgba[i + 3];
      if (alpha < 16) continue;
      r += rgba[i];
      g += rgba[i + 1];
      b += rgba[i + 2];
      count += 1;
    }

    if (count == 0) return null;
    final avg = Color.fromARGB(
      255,
      (r / count).round(),
      (g / count).round(),
      (b / count).round(),
    );

    // Palette aus Cache oder Supabase holen
    final palette = await PaletteService.fetchColors();
    final colorList = palette.map((c) => c.color).toList();
    final nearest = nearestColor(avg, colorList);
    if (nearest == null) return null;
    return hexFromColor(nearest);
  } catch (_) {
    return null;
  }
}
