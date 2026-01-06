import 'package:uuid/uuid.dart';

import '../models/credit_consume_result.dart';

typedef CreditConsumeFn = Future<CreditConsumeResult> Function({
  required int amount,
  required String requestId,
});

class VirtualRoomCreditManager {
  VirtualRoomCreditManager({
    required CreditConsumeFn consume,
    String Function()? requestIdFactory,
  })  : _consume = consume,
        _requestIdFactory = requestIdFactory ?? _defaultRequestId;

  final CreditConsumeFn _consume;
  final String Function() _requestIdFactory;

  bool _busy = false;
  String? _pendingRequestId;

  bool get isBusy => _busy;
  String? get pendingRequestId => _pendingRequestId;

  Future<CreditConsumeResult> consume({
    int amount = 1,
    bool isRetry = false,
  }) async {
    if (_busy) {
      return const CreditConsumeResult(
        ok: false,
        message: 'busy',
        balance: null,
      );
    }

    _busy = true;

    final requestId =
        isRetry && _pendingRequestId != null ? _pendingRequestId! : _newId();

    if (!isRetry || _pendingRequestId == null) {
      _pendingRequestId = requestId;
    }

    try {
      final result = await _consume(
        amount: amount,
        requestId: requestId,
      );

      if (result.isOk ||
          result.isNotEnoughCredits ||
          result.isProRequired ||
          result.message == 'unknown_response_shape') {
        _pendingRequestId = null;
      }

      return result;
    } catch (_) {
      _pendingRequestId = null;
      rethrow;
    } finally {
      _busy = false;
    }
  }

  String _newId() => _requestIdFactory();
}

String _defaultRequestId() => const Uuid().v4();
