class SafeCall {
  const SafeCall._();

  static T? guard<T>(
    T Function() call, {
    T? fallback,
    void Function(Object error, StackTrace stack)? onError,
  }) {
    try {
      return call();
    } catch (error, stack) {
      if (onError != null) onError(error, stack);
      return fallback;
    }
  }

  static Future<T?> guardAsync<T>(
    Future<T> Function() call, {
    T? fallback,
    void Function(Object error, StackTrace stack)? onError,
  }) async {
    try {
      return await call();
    } catch (error, stack) {
      if (onError != null) onError(error, stack);
      return fallback;
    }
  }
}
