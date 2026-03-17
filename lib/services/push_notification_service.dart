import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Firebase muss im Background-Isolate initialisiert sein.
  await Firebase.initializeApp();
  debugPrint('Push (background): ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService({
    SupabaseClient? client,
    FirebaseMessaging? messaging,
  })  : _client = client ?? SupabaseService.client,
        _messaging = messaging;

  final SupabaseClient _client;
  FirebaseMessaging? _messaging;

  bool _initialized = false;
  bool _firebaseReady = false;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  bool get isReady => _firebaseReady;

  /// Stream für Notification-Taps mit projectId.
  /// Shell/UI kann darauf lauschen und zum Projekt navigieren.
  final StreamController<String> _notificationTapController =
      StreamController<String>.broadcast();

  Stream<String> get onNotificationTap => _notificationTapController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase init failed: $e');
      return;
    }

    _messaging ??= FirebaseMessaging.instance;

    await _messaging!.setAutoInitEnabled(true);
    await _messaging!.setForegroundNotificationPresentationOptions(
      // Push nur im Hintergrund anzeigen (Render-Fertig)
      alert: false,
      badge: false,
      sound: false,
    );

    // Background-Handler (eigenes Isolate)
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Foreground-Handler (App offen)
    _onMessageSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // User tippt auf Notification (App war im Hintergrund/geschlossen)
    _onMessageOpenedAppSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // App wurde durch Notification-Tap gestartet (cold start)
    final initial = await _messaging!.getInitialMessage();
    if (initial != null) {
      _handleNotificationTap(initial);
    }

    _onTokenRefreshSub = _messaging!.onTokenRefresh.listen((token) {
      _upsertToken(token);
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Push (foreground): ${message.messageId}');
    // Im Vordergrund zeigen wir keine System-Notification,
    // da der User die App aktiv nutzt.
  }

  void _handleNotificationTap(RemoteMessage message) {
    final projectId = message.data['projectId'] as String?;
    if (projectId != null && projectId.isNotEmpty) {
      _notificationTapController.add(projectId);
    }
  }

  Future<bool> ensurePermissionAndRegister() async {
    if (!_firebaseReady) return false;
    final settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final allowed =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!allowed) return false;
    await registerToken();
    return true;
  }

  Future<void> registerToken() async {
    if (!_firebaseReady) return;
    final user = _client.auth.currentUser;
    if (user == null) return;
    final token = await _messaging!.getToken();
    if (token == null || token.isEmpty) return;
    await _upsertToken(token, userId: user.id);
  }

  Future<void> unregisterToken() async {
    if (!_firebaseReady) return;
    final token = await _messaging!.getToken();
    if (token == null || token.isEmpty) return;
    try {
      await _client.from('push_tokens').delete().eq('token', token);
    } catch (e) {
      if (_isMissingTableError(e)) return;
      debugPrint('Push token delete failed: $e');
    }
  }

  void dispose() {
    _onMessageSub?.cancel();
    _onMessageOpenedAppSub?.cancel();
    _onTokenRefreshSub?.cancel();
    _notificationTapController.close();
  }

  Future<void> _upsertToken(String token, {String? userId}) async {
    final user = _client.auth.currentUser;
    final resolvedUserId = userId ?? user?.id;
    if (resolvedUserId == null) return;
    final platform = Platform.isIOS ? 'ios' : 'android';
    final payload = {
      'user_id': resolvedUserId,
      'token': token,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      await _client.from('push_tokens').upsert(payload, onConflict: 'token');
    } catch (e) {
      if (_isMissingTableError(e)) return;
      debugPrint('Push token upsert failed: $e');
    }
  }

  bool _isMissingTableError(Object error) {
    if (error is PostgrestException) {
      final code = (error.code ?? '').toUpperCase();
      if (code == 'PGRST205' || code == '42P01') return true;
      final message = error.message.toLowerCase();
      if (message.contains('could not find the table') ||
          message.contains('schema cache')) {
        return true;
      }
    }
    final raw = error.toString().toLowerCase();
    return raw.contains('could not find the table') ||
        raw.contains('schema cache');
  }
}
