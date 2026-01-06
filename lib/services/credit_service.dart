import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/credit_consume_result.dart';
import 'supabase_service.dart';

class CreditService {
  CreditService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<CreditConsumeResult> consumeCredit({
    required int amount,
    required String requestId,
  }) async {
    final res = await _client.rpc('consume_credit', params: {
      'p_amount': amount,
      'p_request_id': requestId,
    });

    final data = _asMap(res);
    final ok = data['ok'] == true;
    final message = data['message']?.toString() ?? 'unknown';
    final balance = (data['credits_balance'] as num?)?.toInt();

    return CreditConsumeResult(
      ok: ok,
      message: message,
      balance: balance,
    );
  }

  Map<String, dynamic> _asMap(dynamic res) {
    if (kDebugMode) {
      debugPrint('consume_credit response type: ${res.runtimeType}');
    }

    if (res is Map<String, dynamic>) {
      _logKeys(res);
      return res;
    }
    if (res is Map) {
      final mapped = Map<String, dynamic>.from(res);
      _logKeys(mapped);
      return mapped;
    }
    if (res is List && res.isNotEmpty && res.first is Map) {
      final mapped = Map<String, dynamic>.from(res.first as Map);
      _logKeys(mapped);
      return mapped;
    }
    if (kDebugMode) {
      debugPrint('consume_credit unknown_response_shape: $res');
    }
    return const {
      'ok': false,
      'message': 'unknown_response_shape',
      'credits_balance': null,
    };
  }

  void _logKeys(Map<String, dynamic> data) {
    if (kDebugMode) {
      debugPrint('consume_credit keys: ${data.keys.toList()}');
    }
  }
}
