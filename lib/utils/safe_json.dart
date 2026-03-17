import 'dart:convert';

class SafeJson {
  const SafeJson._();

  static Map<String, dynamic>? decodeMap(String? source) {
    if (source == null || source.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  static List<dynamic>? decodeList(String? source) {
    if (source == null || source.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(source);
      if (decoded is List) return decoded;
    } catch (_) {}
    return null;
  }
}
