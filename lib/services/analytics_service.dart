import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AnalyticsService {
  AnalyticsService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  static final AnalyticsService instance = AnalyticsService();

  Future<void> logEvent(
    String eventName, {
    String? source,
    Map<String, dynamic>? payload,
  }) async {
    final name = eventName.trim();
    if (name.isEmpty) return;

    final userId = _client.auth.currentUser?.id;
    final data = <String, dynamic>{
      'event_name': name,
      if (source != null) 'source': source,
      'user_id': userId,
      if (payload != null && payload.isNotEmpty) 'payload': payload,
    };

    try {
      await _client.from('analytics_events').insert(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AnalyticsService logEvent failed: $e');
      }
    }
  }
}
