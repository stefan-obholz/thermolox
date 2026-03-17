import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class SafeHttp {
  const SafeHttp._();

  static Future<Uint8List?> downloadBytes(
    String url, {
    int retries = 1,
    Duration timeout = const Duration(seconds: 15),
    Duration retryDelay = const Duration(milliseconds: 250),
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    for (var attempt = 0; attempt <= retries; attempt += 1) {
      try {
        final res = await http.get(uri).timeout(timeout);
        if (res.statusCode == 200) return res.bodyBytes;
      } catch (_) {}
      if (attempt < retries) {
        await Future.delayed(retryDelay);
      }
    }
    return null;
  }
}
