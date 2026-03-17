import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'analytics_service.dart';
import 'consent_service.dart';

class ErrorLoggingService {
  ErrorLoggingService({AnalyticsService? analytics})
      : _analytics = analytics ?? AnalyticsService.instance;

  static final ErrorLoggingService instance = ErrorLoggingService();

  final AnalyticsService _analytics;

  static const _dsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  static bool get _sentryEnabled => _dsn.isNotEmpty;

  /// Call once before runApp inside SentryFlutter.init.
  static Future<void> initialize() async {
    if (!_sentryEnabled) {
      if (kDebugMode) debugPrint('Sentry DSN not set — skipping init');
      return;
    }
    await SentryFlutter.init((options) {
      options.dsn = _dsn;
      options.tracesSampleRate = kDebugMode ? 1.0 : 0.2;
      options.environment = kDebugMode ? 'debug' : 'production';
      options.sendDefaultPii = false;
      options.beforeSend = (event, hint) {
        if (!ConsentService.instance.analyticsAllowed) return null;
        return event;
      };
    });
  }

  Future<void> logFlutterError(FlutterErrorDetails details) async {
    final extras = <String, dynamic>{};
    final context = details.context?.toDescription();
    if (context != null && context.isNotEmpty) {
      extras['context'] = context;
    }
    if (details.library != null && details.library!.isNotEmpty) {
      extras['library'] = details.library;
    }
    await logError(
      details.exception,
      details.stack,
      source: 'flutter',
      extras: extras.isEmpty ? null : extras,
    );
  }

  Future<void> logError(
    Object error,
    StackTrace? stack, {
    String? source,
    Map<String, dynamic>? extras,
  }) async {
    // Send to Sentry
    if (_sentryEnabled) {
      try {
        await Sentry.captureException(
          error,
          stackTrace: stack,
          withScope: (scope) {
            if (source != null) scope.setTag('source', source);
            if (extras != null) {
              scope.setContexts('extras', extras);
            }
          },
        );
      } catch (_) {}
    }

    // Also log to analytics
    final payload = <String, dynamic>{
      'message': error.toString(),
      if (stack != null) 'stack': stack.toString(),
      if (extras != null && extras.isNotEmpty) 'extras': extras,
    };

    try {
      await _analytics.logEvent(
        'error',
        source: source,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ErrorLoggingService failed: $e');
      }
    }
  }
}
