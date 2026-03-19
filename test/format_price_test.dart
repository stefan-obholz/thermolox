import 'package:flutter_test/flutter_test.dart';

import 'package:everloxx/utils/format_price.dart';

void main() {
  group('formatPrice', () {
    test('formats integer price', () {
      expect(formatPrice(10), '10,00 €');
    });

    test('formats decimal price', () {
      expect(formatPrice(9.9), '9,90 €');
    });

    test('formats zero', () {
      expect(formatPrice(0), '0,00 €');
    });

    test('rounds to 2 decimals', () {
      expect(formatPrice(3.456), '3,46 €');
    });

    test('formats large number with thousand separator', () {
      expect(formatPrice(1234.5), '1.234,50 €');
    });

    test('formats very large number', () {
      expect(formatPrice(1234567.89), '1.234.567,89 €');
    });
  });
}
