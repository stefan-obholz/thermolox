import 'package:flutter_test/flutter_test.dart';

import 'package:thermolox/utils/safe_json.dart';

void main() {
  group('SafeJson.decodeMap', () {
    test('parses valid JSON object', () {
      final result = SafeJson.decodeMap('{"key": "value"}');
      expect(result, isNotNull);
      expect(result!['key'], 'value');
    });

    test('returns null for JSON array', () {
      expect(SafeJson.decodeMap('[1, 2, 3]'), isNull);
    });

    test('returns null for invalid JSON', () {
      expect(SafeJson.decodeMap('not json'), isNull);
    });

    test('returns null for null', () {
      expect(SafeJson.decodeMap(null), isNull);
    });

    test('returns null for empty string', () {
      expect(SafeJson.decodeMap(''), isNull);
    });

    test('returns null for whitespace', () {
      expect(SafeJson.decodeMap('   '), isNull);
    });
  });

  group('SafeJson.decodeList', () {
    test('parses valid JSON array', () {
      final result = SafeJson.decodeList('[1, 2, 3]');
      expect(result, isNotNull);
      expect(result!.length, 3);
    });

    test('returns null for JSON object', () {
      expect(SafeJson.decodeList('{"key": "value"}'), isNull);
    });

    test('returns null for invalid JSON', () {
      expect(SafeJson.decodeList('not json'), isNull);
    });

    test('returns null for null', () {
      expect(SafeJson.decodeList(null), isNull);
    });
  });
}
