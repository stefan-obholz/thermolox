import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central design tokens from Supabase – single source of truth for all styling.
/// Used by both App (ThemeData) and Website (/style.css from Worker).
class DesignTokenService {
  static Map<String, dynamic>? _tokens;
  static const _diskKey = 'design_tokens_cache';

  // ── Hardcoded fallback (matches Supabase seed) ──
  static const _defaults = {
    'colors': {
      'primary': '#efd2a7',
      'primaryHover': '#efd2a7',
      'background': '#FFFFFF',
      'backgroundWarm': '#FFF8F5',
      'foreground': '#2D2926',
      'foregroundLight': '#FFF8F5',
      'dark': '#1A1614',
      'accent': '#efd2a7',
      'border': '#E8D5CC',
    },
    'fonts': {
      'heading': 'Times New Roman',
      'body': 'Lato',
      'headingWeight': 700,
      'bodyWeight': 400,
    },
    'brand': {
      'name': 'EVERLOXX',
      'nameFull': 'EVERLOXX',
      'tagline': 'Dein Zuhause. Dein Style.',
    },
    'icons': {'color': '#efd2a7'},
    'buttons': {'radius': 40},
    'cards': {'radius': 12},
  };

  /// Load tokens: Supabase → Disk cache → Hardcoded defaults.
  static Future<Map<String, dynamic>> load() async {
    if (_tokens != null) return _tokens!;

    // 1. Supabase
    try {
      final response = await Supabase.instance.client
          .from('design_tokens')
          .select('tokens')
          .eq('is_active', true)
          .limit(1)
          .single()
          .timeout(const Duration(seconds: 5));

      _tokens = response['tokens'] as Map<String, dynamic>;
      _saveToDisk(_tokens!);
      return _tokens!;
    } catch (_) {}

    // 2. Disk cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskKey);
      if (raw != null) {
        _tokens = jsonDecode(raw) as Map<String, dynamic>;
        return _tokens!;
      }
    } catch (_) {}

    // 3. Hardcoded defaults
    _tokens = Map<String, dynamic>.from(_defaults);
    return _tokens!;
  }

  static void invalidate() => _tokens = null;

  // ── Typed accessors ──

  static Color get primary => _hex('colors.primary', '#efd2a7');
  static Color get primaryHover => _hex('colors.primaryHover', '#efd2a7');
  static Color get background => _hex('colors.background', '#FFFFFF');
  static Color get backgroundWarm => _hex('colors.backgroundWarm', '#FFF8F5');
  static Color get foreground => _hex('colors.foreground', '#2D2926');
  static Color get foregroundLight => _hex('colors.foregroundLight', '#FFF8F5');
  static Color get dark => _hex('colors.dark', '#1A1614');
  static Color get accent => _hex('colors.accent', '#efd2a7');
  static Color get iconColor => _hex('icons.color', '#efd2a7');

  static String get fontHeading => _str('fonts.heading', 'Times New Roman');
  static String get fontBody => _str('fonts.body', 'Lato');
  static int get headingWeight => _int('fonts.headingWeight', 700);
  static int get bodyWeight => _int('fonts.bodyWeight', 400);

  static String get brandName => _str('brand.name', 'EVERLOXX');
  static String get brandNameFull => _str('brand.nameFull', 'EVERLOXX');
  static String get brandTagline => _str('brand.tagline', 'Dein Zuhause. Dein Style.');

  static double get buttonRadius => _double('buttons.radius', 40);
  static double get cardRadius => _double('cards.radius', 12);

  // ── Helpers ──

  static dynamic _get(String path) {
    final tokens = _tokens ?? _defaults;
    final parts = path.split('.');
    dynamic current = tokens;
    for (final p in parts) {
      if (current is Map) {
        current = current[p];
      } else {
        return null;
      }
    }
    return current;
  }

  static Color _hex(String path, String fallback) {
    final hex = (_get(path) as String?) ?? fallback;
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  static String _str(String path, String fallback) =>
      (_get(path) as String?) ?? fallback;

  static int _int(String path, int fallback) =>
      (_get(path) as num?)?.toInt() ?? fallback;

  static double _double(String path, double fallback) =>
      (_get(path) as num?)?.toDouble() ?? fallback;

  static Future<void> _saveToDisk(Map<String, dynamic> tokens) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_diskKey, jsonEncode(tokens));
    } catch (_) {}
  }
}
