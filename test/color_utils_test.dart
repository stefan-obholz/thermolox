import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thermolox/utils/color_utils.dart';

void main() {
  group('isValidHex', () {
    test('accepts 6-digit hex', () {
      expect(isValidHex('FF0000'), isTrue);
      expect(isValidHex('#00FF00'), isTrue);
    });

    test('accepts 3-digit hex', () {
      expect(isValidHex('abc'), isTrue);
      expect(isValidHex('#fff'), isTrue);
    });

    test('rejects invalid', () {
      expect(isValidHex('xyz'), isFalse);
      expect(isValidHex('12345'), isFalse);
      expect(isValidHex(''), isFalse);
    });
  });

  group('normalizeHex', () {
    test('expands 3-digit', () {
      expect(normalizeHex('#abc'), '#AABBCC');
    });

    test('pads short', () {
      expect(normalizeHex('F0'), '#F00000');
    });

    test('truncates long', () {
      expect(normalizeHex('AABBCCDD'), '#AABBCC');
    });

    test('uppercases', () {
      expect(normalizeHex('ff0000'), '#FF0000');
    });
  });

  group('colorFromHex', () {
    test('returns Color for valid hex', () {
      final c = colorFromHex('#FF0000');
      expect(c, isNotNull);
      expect((c!.r * 255).round(), 255);
      expect((c.g * 255).round(), 0);
      expect((c.b * 255).round(), 0);
    });

    test('returns null for invalid', () {
      expect(colorFromHex('zzz'), isNull);
    });
  });

  group('hexFromColor', () {
    test('converts red', () {
      expect(hexFromColor(const Color(0xFFFF0000)), '#FF0000');
    });

    test('converts white', () {
      expect(hexFromColor(const Color(0xFFFFFFFF)), '#FFFFFF');
    });

    test('converts black', () {
      expect(hexFromColor(const Color(0xFF000000)), '#000000');
    });
  });

  group('colorDistanceSquared', () {
    test('same color is zero', () {
      const c = Color(0xFFFF0000);
      expect(colorDistanceSquared(c, c), 0);
    });

    test('black to white', () {
      expect(
        colorDistanceSquared(
          const Color(0xFF000000),
          const Color(0xFFFFFFFF),
        ),
        255 * 255 * 3,
      );
    });
  });

  group('nearestColor', () {
    test('finds exact match', () {
      const target = Color(0xFFFF0000);
      final palette = [
        const Color(0xFF00FF00),
        const Color(0xFFFF0000),
        const Color(0xFF0000FF),
      ];
      expect(nearestColor(target, palette), const Color(0xFFFF0000));
    });

    test('returns null for empty palette', () {
      expect(nearestColor(const Color(0xFFFF0000), []), isNull);
    });

    test('finds closest', () {
      const target = Color(0xFFFE0000); // almost red
      final palette = [
        const Color(0xFF00FF00),
        const Color(0xFFFF0000),
      ];
      expect(nearestColor(target, palette), const Color(0xFFFF0000));
    });
  });

  group('nearestPaletteHex', () {
    test('returns nearest hex', () {
      final palette = [
        const Color(0xFFFF0000),
        const Color(0xFF00FF00),
      ];
      expect(nearestPaletteHex('#FE0101', palette), '#FF0000');
    });

    test('returns null for invalid input', () {
      expect(nearestPaletteHex('zzz', [const Color(0xFFFF0000)]), isNull);
    });
  });
}
