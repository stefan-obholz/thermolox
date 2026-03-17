import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/palette_color.dart';

class PaletteService {
  static List<PaletteColor>? _cache;
  static const _diskKey = 'palette_colors_cache';

  /// Fetches colors: Supabase (SSOT) → Disk-Cache.
  static Future<List<PaletteColor>> fetchColors() async {
    if (_cache != null) return _cache!;

    // 1. Try Supabase
    try {
      final response = await Supabase.instance.client
          .from('palette_colors')
          .select('hex, name, group_name, shade_index, description')
          .eq('status', 'active')
          .order('sort_order')
          .timeout(const Duration(seconds: 10));

      final rows = response as List<dynamic>;
      if (rows.isNotEmpty) {
        final list = rows
            .map((e) => PaletteColor.fromJson(e as Map<String, dynamic>))
            .toList();
        _cache = list;
        _saveToDisk(rows);
        if (kDebugMode) debugPrint('Palette loaded from Supabase: ${list.length}');
        return list;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Supabase palette fetch failed: $e');
    }

    // 2. Fallback: Disk-Cache
    return _loadFromDisk();
  }

  /// Beschreibung für ein Produkt anhand des Titels aus der Palette holen.
  static Future<String?> descriptionForProduct(String productTitle) async {
    final colors = await fetchColors();
    final lower = productTitle.trim().toLowerCase();
    for (final c in colors) {
      if (c.name.trim().toLowerCase() == lower) return c.description;
    }
    return null;
  }

  static List<PaletteGroup> groupColors(List<PaletteColor> colors) {
    final map = <String, List<PaletteColor>>{};
    for (final c in colors) {
      map.putIfAbsent(c.groupName, () => []).add(c);
    }
    return map.entries
        .map((e) {
          final sorted = List<PaletteColor>.from(e.value)
            ..sort((a, b) => a.shadeIndex.compareTo(b.shadeIndex));
          return PaletteGroup(name: e.key, shades: sorted);
        })
        .toList();
  }

  static void invalidate() => _cache = null;

  // ---- Disk-Cache ----

  static Future<void> _saveToDisk(List<dynamic> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_diskKey, jsonEncode(rows));
    } catch (_) {}
  }

  static Future<List<PaletteColor>> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskKey);
      if (raw == null) return [];
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => PaletteColor.fromJson(e as Map<String, dynamic>))
          .toList();
      _cache = list;
      if (kDebugMode) debugPrint('Palette loaded from disk cache: ${list.length}');
      return list;
    } catch (_) {
      return [];
    }
  }
}
