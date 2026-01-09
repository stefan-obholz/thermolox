import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_service.dart';
import 'supabase_service.dart';

class LegalGateService extends ChangeNotifier {
  LegalGateService._internal({
    SupabaseClient? client,
    ProfileService? profileService,
  })  : _client = client ?? SupabaseService.client,
        _profileService = profileService ?? ProfileService();

  static final LegalGateService instance = LegalGateService._internal();

  static const String termsVersion = 'v1';
  static const String privacyVersion = 'v1';

  static const String _termsVersionKey = 'legal_terms_version';
  static const String _privacyVersionKey = 'legal_privacy_version';
  static const String _termsAcceptedAtKey = 'legal_terms_accepted_at';
  static const String _privacyAcceptedAtKey = 'legal_privacy_accepted_at';

  final SupabaseClient _client;
  final ProfileService _profileService;
  StreamSubscription<AuthState>? _authSub;

  bool _loaded = false;
  String? _storedTermsVersion;
  String? _storedPrivacyVersion;
  DateTime? _termsAcceptedAt;
  DateTime? _privacyAcceptedAt;

  bool get isLoaded => _loaded;
  bool get isAccepted =>
      _loaded &&
      _storedTermsVersion == termsVersion &&
      _storedPrivacyVersion == privacyVersion &&
      _termsAcceptedAt != null &&
      _privacyAcceptedAt != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _storedTermsVersion = prefs.getString(_termsVersionKey);
    _storedPrivacyVersion = prefs.getString(_privacyVersionKey);
    _termsAcceptedAt = _parseDate(prefs.getString(_termsAcceptedAtKey));
    _privacyAcceptedAt = _parseDate(prefs.getString(_privacyAcceptedAtKey));
    _loaded = true;
    notifyListeners();

    _authSub ??= _client.auth.onAuthStateChange.listen((_) {
      _syncToServerIfNeeded();
    });

    await _syncToServerIfNeeded();
  }

  Future<void> accept() async {
    final now = DateTime.now().toUtc();
    _termsAcceptedAt = now;
    _privacyAcceptedAt = now;
    _storedTermsVersion = termsVersion;
    _storedPrivacyVersion = privacyVersion;
    await _persist();
    _loaded = true;
    notifyListeners();
    await _syncToServerIfNeeded();
  }

  Future<void> syncToServerIfNeeded() => _syncToServerIfNeeded();

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_storedTermsVersion != null) {
      await prefs.setString(_termsVersionKey, _storedTermsVersion!);
    }
    if (_storedPrivacyVersion != null) {
      await prefs.setString(_privacyVersionKey, _storedPrivacyVersion!);
    }
    if (_termsAcceptedAt != null) {
      await prefs.setString(
        _termsAcceptedAtKey,
        _termsAcceptedAt!.toIso8601String(),
      );
    }
    if (_privacyAcceptedAt != null) {
      await prefs.setString(
        _privacyAcceptedAtKey,
        _privacyAcceptedAt!.toIso8601String(),
      );
    }
  }

  Future<void> _syncToServerIfNeeded() async {
    if (!isAccepted) return;
    final user = _client.auth.currentUser;
    if (user == null) return;
    final termsAt = _termsAcceptedAt;
    final privacyAt = _privacyAcceptedAt;
    if (termsAt == null || privacyAt == null) return;
    try {
      await _profileService.recordLegalAcceptance(
        userId: user.id,
        termsAcceptedAt: termsAt,
        privacyAcceptedAt: privacyAt,
        termsVersion: termsVersion,
        privacyVersion: privacyVersion,
        source: 'app_gate',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LegalGateService sync failed: $e');
      }
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
