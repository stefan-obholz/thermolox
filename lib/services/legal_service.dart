import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LegalPage {
  final String slug;
  final String title;
  final String bodyHtml;
  final int sortOrder;

  const LegalPage({
    required this.slug,
    required this.title,
    required this.bodyHtml,
    required this.sortOrder,
  });

  factory LegalPage.fromJson(Map<String, dynamic> json) => LegalPage(
        slug: json['slug'] as String,
        title: json['title'] as String,
        bodyHtml: json['body_html'] as String? ?? '',
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'title': title,
        'body_html': bodyHtml,
        'sort_order': sortOrder,
      };
}

class LegalService {
  static const _cacheKey = 'legal_pages_cache';
  static List<LegalPage>? _cache;

  static Future<List<LegalPage>> fetchPages() async {
    if (_cache != null) return _cache!;

    // 1. Try Supabase
    try {
      final response = await Supabase.instance.client
          .from('legal_pages')
          .select()
          .order('sort_order')
          .timeout(const Duration(seconds: 10));

      final rows = response as List<dynamic>;
      if (rows.isNotEmpty) {
        final pages = rows
            .map((r) => LegalPage.fromJson(r as Map<String, dynamic>))
            .toList();
        _cache = pages;
        _saveToDisk(pages);
        return pages;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Legal pages fetch failed: $e');
    }

    // 2. Fallback: disk cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        final pages = list
            .map((e) => LegalPage.fromJson(e as Map<String, dynamic>))
            .toList();
        _cache = pages;
        return pages;
      }
    } catch (_) {}

    return [];
  }

  static Future<void> _saveToDisk(List<LegalPage> pages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _cacheKey, jsonEncode(pages.map((p) => p.toJson()).toList()));
    } catch (_) {}
  }

  /// Get a specific page by slug
  static Future<LegalPage?> getPage(String slug) async {
    final pages = await fetchPages();
    try {
      return pages.firstWhere((p) => p.slug == slug);
    } catch (_) {
      return null;
    }
  }

  static void clearCache() => _cache = null;
}
