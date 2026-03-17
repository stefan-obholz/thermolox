import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/content_item.dart';

/// Fetches pages and blog articles from Supabase with disk cache fallback.
class ContentService {
  static List<ContentItem>? _cache;
  static const _diskKey = 'content_cache';

  /// All content (pages + articles), sorted by type then sort_order.
  static Future<List<ContentItem>> fetchAll() async {
    if (_cache != null) return _cache!;

    try {
      final response = await Supabase.instance.client
          .from('content')
          .select()
          .eq('is_visible', true)
          .order('sort_order')
          .order('published_at')
          .timeout(const Duration(seconds: 10));

      final rows = response as List<dynamic>;
      if (rows.isNotEmpty) {
        final items = rows
            .map((r) => ContentItem.fromSupabase(r as Map<String, dynamic>))
            .toList();
        _cache = items;
        _saveToDisk(rows);
        if (kDebugMode) debugPrint('Content loaded from Supabase: ${items.length}');
        return items;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Supabase content fetch failed: $e');
    }

    // Fallback: disk cache
    return _loadFromDisk();
  }

  /// Only blog articles, newest first.
  static Future<List<ContentItem>> fetchArticles() async {
    final all = await fetchAll();
    final articles = all.where((c) => c.isArticle).toList()
      ..sort((a, b) =>
          (b.publishedAt ?? DateTime(2000)).compareTo(a.publishedAt ?? DateTime(2000)));
    return articles;
  }

  /// Only pages.
  static Future<List<ContentItem>> fetchPages() async {
    final all = await fetchAll();
    return all.where((c) => c.isPage).toList();
  }

  /// Single page by handle (e.g. 'faq', 'technologie').
  static Future<ContentItem?> fetchPage(String handle) async {
    final all = await fetchAll();
    try {
      return all.firstWhere((c) => c.isPage && c.handle == handle);
    } catch (_) {
      return null;
    }
  }

  /// Single article by handle.
  static Future<ContentItem?> fetchArticle(String handle) async {
    final all = await fetchAll();
    try {
      return all.firstWhere((c) => c.isArticle && c.handle == handle);
    } catch (_) {
      return null;
    }
  }

  static void invalidate() => _cache = null;

  // ---- Disk Cache ----

  static Future<void> _saveToDisk(List<dynamic> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_diskKey, jsonEncode(rows));
    } catch (_) {}
  }

  static Future<List<ContentItem>> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskKey);
      if (raw == null) return [];
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => ContentItem.fromSupabase(e as Map<String, dynamic>))
          .toList();
      _cache = list;
      if (kDebugMode) debugPrint('Content loaded from disk cache: ${list.length}');
      return list;
    } catch (_) {
      return [];
    }
  }
}
