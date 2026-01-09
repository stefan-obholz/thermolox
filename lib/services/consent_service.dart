import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:postgrest/postgrest.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';
import '../memory/memory_storage.dart';

class ConsentService extends ChangeNotifier {
  ConsentService._internal({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  static final ConsentService instance = ConsentService._internal();

  static const _analyticsKey = 'consent_analytics';
  static const _analyticsAtKey = 'consent_analytics_at';
  static const _aiKey = 'consent_ai';
  static const _aiAtKey = 'consent_ai_at';

  final SupabaseClient _client;
  StreamSubscription<AuthState>? _authSub;
  Future<User?>? _anonSignInFuture;

  bool _loaded = false;
  bool _analyticsAllowed = false;
  bool _aiAllowed = false;
  DateTime? _analyticsUpdatedAt;
  DateTime? _aiUpdatedAt;

  bool get isLoaded => _loaded;
  bool get analyticsAllowed => _analyticsAllowed;
  bool get aiAllowed => _aiAllowed;
  DateTime? get analyticsUpdatedAt => _analyticsUpdatedAt;
  DateTime? get aiUpdatedAt => _aiUpdatedAt;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _analyticsAllowed = prefs.getBool(_analyticsKey) ?? false;
    _aiAllowed = prefs.getBool(_aiKey) ?? false;
    _analyticsUpdatedAt = _parseDate(prefs.getString(_analyticsAtKey));
    _aiUpdatedAt = _parseDate(prefs.getString(_aiAtKey));
    _loaded = true;
    notifyListeners();

    await _refreshFromServer();
    _authSub ??= _client.auth.onAuthStateChange.listen((_) {
      _refreshFromServer();
    });
  }

  Future<void> setAnalyticsAllowed(bool allowed) async {
    final now = DateTime.now().toUtc();
    _analyticsAllowed = allowed;
    _analyticsUpdatedAt = now;
    await _persistLocal();
    notifyListeners();
    await _syncToServer(
      consentKey: 'analytics',
      allowed: allowed,
      updatedAt: now,
    );
  }

  Future<void> setAiAllowed(bool allowed) async {
    final now = DateTime.now().toUtc();
    _aiAllowed = allowed;
    _aiUpdatedAt = now;
    if (!allowed) {
      await MemoryStorage.clear();
    }
    await _persistLocal();
    notifyListeners();
    await _syncToServer(
      consentKey: 'ai',
      allowed: allowed,
      updatedAt: now,
    );
  }

  Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_analyticsKey);
    await prefs.remove(_analyticsAtKey);
    await prefs.remove(_aiKey);
    await prefs.remove(_aiAtKey);
    await MemoryStorage.clear();

    _analyticsAllowed = false;
    _aiAllowed = false;
    _analyticsUpdatedAt = null;
    _aiUpdatedAt = null;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_analyticsKey, _analyticsAllowed);
    await prefs.setBool(_aiKey, _aiAllowed);
    if (_analyticsUpdatedAt != null) {
      await prefs.setString(
        _analyticsAtKey,
        _analyticsUpdatedAt!.toIso8601String(),
      );
    }
    if (_aiUpdatedAt != null) {
      await prefs.setString(
        _aiAtKey,
        _aiUpdatedAt!.toIso8601String(),
      );
    }
  }

  Future<void> _refreshFromServer() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    Map<String, dynamic>? row;
    try {
      row = await _client
          .from('profiles')
          .select('analytics_consent,analytics_consent_at,ai_consent,ai_consent_at')
          .eq('id', user.id)
          .maybeSingle();
    } catch (e) {
      if (_isMissingColumnError(e)) {
        try {
          row = await _client
              .from('profiles')
              .select(
                'analytics_consent,analytics_consent_at,ai_consent,ai_consent_at',
              )
              .eq('user_id', user.id)
              .maybeSingle();
        } catch (inner) {
          if (_isMissingColumnError(inner)) return;
          if (kDebugMode) {
            debugPrint('ConsentService profile load failed: $inner');
          }
          return;
        }
      } else if (kDebugMode) {
        debugPrint('ConsentService profile load failed: $e');
        return;
      }
    }

    if (row == null) {
      await _syncLocalToServerIfNeeded();
      return;
    }

    var changed = false;
    final serverAnalytics = row['analytics_consent'] as bool?;
    final serverAnalyticsAt = _parseDate(row['analytics_consent_at']);
    if (_shouldApplyServerUpdate(serverAnalyticsAt, _analyticsUpdatedAt) &&
        serverAnalytics != null) {
      _analyticsAllowed = serverAnalytics;
      _analyticsUpdatedAt = serverAnalyticsAt ?? _analyticsUpdatedAt;
      changed = true;
    }

    final serverAi = row['ai_consent'] as bool?;
    final serverAiAt = _parseDate(row['ai_consent_at']);
    if (_shouldApplyServerUpdate(serverAiAt, _aiUpdatedAt) && serverAi != null) {
      _aiAllowed = serverAi;
      _aiUpdatedAt = serverAiAt ?? _aiUpdatedAt;
      changed = true;
    }

    final shouldSyncAnalytics = _analyticsUpdatedAt != null &&
        (serverAnalyticsAt == null ||
            _analyticsUpdatedAt!.isAfter(serverAnalyticsAt));
    final shouldSyncAi =
        _aiUpdatedAt != null &&
            (serverAiAt == null || _aiUpdatedAt!.isAfter(serverAiAt));

    if (changed) {
      await _persistLocal();
      notifyListeners();
    }

    if (shouldSyncAnalytics) {
      await _syncToServer(
        consentKey: 'analytics',
        allowed: _analyticsAllowed,
        updatedAt: _analyticsUpdatedAt!,
      );
    }
    if (shouldSyncAi) {
      await _syncToServer(
        consentKey: 'ai',
        allowed: _aiAllowed,
        updatedAt: _aiUpdatedAt!,
      );
    }
  }

  Future<void> _syncLocalToServerIfNeeded() async {
    if (_analyticsUpdatedAt != null) {
      await _syncToServer(
        consentKey: 'analytics',
        allowed: _analyticsAllowed,
        updatedAt: _analyticsUpdatedAt!,
      );
    }
    if (_aiUpdatedAt != null) {
      await _syncToServer(
        consentKey: 'ai',
        allowed: _aiAllowed,
        updatedAt: _aiUpdatedAt!,
      );
    }
  }

  bool _shouldApplyServerUpdate(DateTime? server, DateTime? local) {
    if (local == null) return true;
    if (server == null) return false;
    return server.isAfter(local);
  }

  Future<void> _syncToServer({
    required String consentKey,
    required bool allowed,
    required DateTime updatedAt,
  }) async {
    var user = _client.auth.currentUser;
    if (user == null && allowed) {
      user = await _ensureAnonymousUser();
    }
    if (user == null) return;

    final data = <String, dynamic>{
      'id': user.id,
      '${consentKey}_consent': allowed,
      '${consentKey}_consent_at': updatedAt.toIso8601String(),
    };

    await _upsertProfile(data);
    if (allowed) {
      await _insertConsentAudit(user.id, consentKey, updatedAt);
    }
  }

  Future<User?> _ensureAnonymousUser() async {
    final existing = _client.auth.currentUser;
    if (existing != null) return existing;

    _anonSignInFuture ??= _signInAnonymously();
    final user = await _anonSignInFuture!;
    _anonSignInFuture = null;
    return user;
  }

  Future<User?> _signInAnonymously() async {
    try {
      final response = await _client.auth.signInAnonymously();
      return response.user ?? _client.auth.currentUser;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ConsentService anonymous sign-in failed: $e');
      }
      return null;
    }
  }

  Future<void> _upsertProfile(Map<String, dynamic> data) async {
    try {
      await _client.from('profiles').upsert(data, onConflict: 'id');
      return;
    } catch (e) {
      if (!_isMissingColumnError(e)) {
        if (kDebugMode) {
          debugPrint('ConsentService profile upsert failed: $e');
        }
        return;
      }
    }

    try {
      final adjusted = Map<String, dynamic>.from(data);
      final userId = adjusted.remove('id');
      adjusted['user_id'] = userId;
      await _client.from('profiles').upsert(adjusted, onConflict: 'user_id');
    } catch (e) {
      if (_isMissingColumnError(e)) return;
      if (kDebugMode) {
        debugPrint('ConsentService profile upsert failed: $e');
      }
    }
  }

  Future<void> _insertConsentAudit(
    String userId,
    String consentKey,
    DateTime updatedAt,
  ) async {
    final column = '${consentKey}_accepted_at';
    final data = <String, dynamic>{
      'user_id': userId,
      column: updatedAt.toIso8601String(),
    };
    try {
      await _client.from('user_consents').insert(data);
    } catch (e) {
      if (_isMissingColumnError(e)) return;
      if (kDebugMode) {
        debugPrint('ConsentService audit insert failed: $e');
      }
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  bool _isMissingColumnError(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      final message = error.message.toLowerCase();
      if (code == '42703') return true;
      return message.contains('column') && message.contains('does not exist');
    }
    return false;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
