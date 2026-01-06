import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri?>? _subscription;
  static bool _initialized = false;
  static String? lastDeepLink;
  static String? lastDeepLinkSource;
  static DateTime? lastDeepLinkAt;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _handleInitialLink();
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleUri(uri, source: 'stream'),
      onError: (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('DeepLink stream error: $error');
        }
      },
    );
  }

  static Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }

  static Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      await _handleUri(uri, source: 'initial');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DeepLink initial error: $e');
      }
    }
  }

  static Future<void> _handleUri(
    Uri? uri, {
    required String source,
  }) async {
    if (uri == null) return;
    lastDeepLink = _sanitizeUri(uri);
    lastDeepLinkSource = source;
    lastDeepLinkAt = DateTime.now();

    if (!_isAuthCallback(uri)) return;

    if (kDebugMode) {
      debugPrint('DeepLink [$source]: $lastDeepLink');
    }

    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      await closeInAppWebView();
      if (kDebugMode) {
        debugPrint('DeepLink [$source]: session updated');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DeepLink [$source] error: $e');
      }
    }
  }

  static bool _isAuthCallback(Uri uri) {
    final fragment = uri.fragment;
    return uri.queryParameters.containsKey('code') ||
        fragment.contains('access_token') ||
        fragment.contains('error_description');
  }

  static String _sanitizeUri(Uri uri) {
    final maskedQuery = Map<String, String>.from(uri.queryParameters);
    const sensitive = {
      'access_token',
      'refresh_token',
      'code',
      'token',
      'id_token',
    };
    for (final key in sensitive) {
      if (maskedQuery.containsKey(key)) {
        maskedQuery[key] = '***';
      }
    }

    final maskedFragment = _sanitizeFragment(uri.fragment);
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.port,
      path: uri.path,
      queryParameters: maskedQuery.isEmpty ? null : maskedQuery,
      fragment: maskedFragment,
    ).toString();
  }

  static String _sanitizeFragment(String fragment) {
    if (fragment.isEmpty) return fragment;
    final parts = fragment.split('&');
    final masked = parts.map((part) {
      final idx = part.indexOf('=');
      if (idx == -1) return part;
      final key = part.substring(0, idx);
      if (key == 'access_token' ||
          key == 'refresh_token' ||
          key == 'id_token' ||
          key == 'token') {
        return '$key=***';
      }
      return part;
    }).toList();
    return masked.join('&');
  }
}
