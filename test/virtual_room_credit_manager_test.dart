import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:thermolox/controllers/virtual_room_credit_manager.dart';
import 'package:thermolox/models/credit_consume_result.dart';

void main() {
  test('credits consume ok clears request id', () async {
    final seen = <String>[];
    final manager = VirtualRoomCreditManager(
      requestIdFactory: () => 'req-1',
      consume: ({required int amount, required String requestId}) async {
        seen.add(requestId);
        return const CreditConsumeResult(
          ok: true,
          message: 'ok',
          balance: 9,
        );
      },
    );

    final result = await manager.consume();

    expect(result.isOk, isTrue);
    expect(seen, ['req-1']);
    expect(manager.pendingRequestId, isNull);
    expect(manager.isBusy, isFalse);
  });

  test('ok_duplicate is treated as success', () async {
    final manager = VirtualRoomCreditManager(
      requestIdFactory: () => 'req-dup',
      consume: ({required int amount, required String requestId}) async {
        return const CreditConsumeResult(
          ok: false,
          message: 'ok_duplicate',
          balance: 9,
        );
      },
    );

    final result = await manager.consume();

    expect(result.isOk, isTrue);
    expect(manager.pendingRequestId, isNull);
  });

  test('not_enough_credits clears request id', () async {
    final manager = VirtualRoomCreditManager(
      requestIdFactory: () => 'req-no-credits',
      consume: ({required int amount, required String requestId}) async {
        return const CreditConsumeResult(
          ok: false,
          message: 'not_enough_credits',
          balance: 0,
        );
      },
    );

    final result = await manager.consume();

    expect(result.isNotEnoughCredits, isTrue);
    expect(manager.pendingRequestId, isNull);
  });

  test('pro_required clears request id', () async {
    final manager = VirtualRoomCreditManager(
      requestIdFactory: () => 'req-pro',
      consume: ({required int amount, required String requestId}) async {
        return const CreditConsumeResult(
          ok: false,
          message: 'pro_required',
          balance: null,
        );
      },
    );

    final result = await manager.consume();

    expect(result.isProRequired, isTrue);
    expect(manager.pendingRequestId, isNull);
  });

  test('timeout clears request id for new attempt', () async {
    var callCount = 0;
    String? retryRequestId;
    final ids = ['req-timeout-1', 'req-timeout-2'];

    final manager = VirtualRoomCreditManager(
      requestIdFactory: () => ids.removeAt(0),
      consume: ({required int amount, required String requestId}) async {
        callCount += 1;
        if (callCount == 1) {
          throw TimeoutException('timeout');
        }
        retryRequestId = requestId;
        return const CreditConsumeResult(
          ok: true,
          message: 'ok',
          balance: 8,
        );
      },
    );

    try {
      await manager.consume();
    } catch (_) {}

    expect(manager.pendingRequestId, isNull);

    final result = await manager.consume(isRetry: true);

    expect(result.isOk, isTrue);
    expect(retryRequestId, 'req-timeout-2');
    expect(manager.pendingRequestId, isNull);
  });

  test('unknown_response_shape clears request id', () async {
    final manager = VirtualRoomCreditManager(
      requestIdFactory: () => 'req-unknown',
      consume: ({required int amount, required String requestId}) async {
        return const CreditConsumeResult(
          ok: false,
          message: 'unknown_response_shape',
          balance: null,
        );
      },
    );

    final result = await manager.consume();

    expect(result.message, 'unknown_response_shape');
    expect(manager.pendingRequestId, isNull);
  });
}
