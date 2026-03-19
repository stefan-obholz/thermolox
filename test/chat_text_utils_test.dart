import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:everloxx/chat/chat_text_utils.dart';

void main() {
  group('normalizeHex', () {
    test('adds hash and uppercases', () {
      expect(normalizeHex('ff0000'), '#FF0000');
    });

    test('handles existing hash', () {
      expect(normalizeHex('#abc'), '#AABBCC');
    });

    test('pads short hex', () {
      expect(normalizeHex('f0'), '#F00000');
    });

    test('trims whitespace', () {
      expect(normalizeHex('  #abc  '), '#AABBCC');
    });
  });

  group('colorFromHexValue', () {
    test('returns correct int for red', () {
      final val = colorFromHexValue('#FF0000');
      expect(val, 0xFFFF0000);
    });

    test('returns correct int for white', () {
      final val = colorFromHexValue('#FFFFFF');
      expect(val, 0xFFFFFFFF);
    });

    test('handles invalid hex gracefully', () {
      final val = colorFromHexValue('zzzzzz');
      expect(val, 0xFF777777);
    });
  });

  group('extractHexColors', () {
    test('finds single hex color', () {
      expect(extractHexColors('Die Farbe ist #FF0000'), ['#FF0000']);
    });

    test('finds multiple hex colors', () {
      expect(
        extractHexColors('#aabbcc und #112233'),
        ['#AABBCC', '#112233'],
      );
    });

    test('deduplicates', () {
      expect(extractHexColors('#abc #abc'), ['#AABBCC']);
    });

    test('returns empty for no hex', () {
      expect(extractHexColors('keine Farbe hier'), isEmpty);
    });
  });

  group('extractHexColorsLoose', () {
    test('finds hex without hash', () {
      final result = extractHexColorsLoose('FF0000');
      expect(result, ['#FF0000']);
    });

    test('finds hex with hash', () {
      final result = extractHexColorsLoose('#abc');
      expect(result, ['#AABBCC']);
    });
  });

  group('normalizeMatchText', () {
    test('lowercases and strips special chars', () {
      expect(normalizeMatchText('Mein Wohnzimmer!'), 'mein wohnzimmer');
    });

    test('preserves umlauts', () {
      expect(normalizeMatchText('Küche'), 'küche');
    });
  });

  group('shorten', () {
    test('returns full string if short', () {
      expect(shorten('hello', 10), 'hello');
    });

    test('truncates long strings', () {
      expect(shorten('hello world', 5), 'hello...');
    });

    test('handles null', () {
      expect(shorten(null), '');
    });
  });

  group('formatNumber', () {
    test('formats with comma', () {
      expect(formatNumber(3.14), '3,1');
    });

    test('formats with 0 decimals', () {
      expect(formatNumber(3.7, decimals: 0), '4');
    });
  });

  group('normalizeUmlautText', () {
    test('replaces ae/oe/ue variants', () {
      expect(normalizeUmlautText('Waende'), 'Wände');
      expect(normalizeUmlautText('moechtest'), 'möchtest');
      expect(normalizeUmlautText('fuer'), 'für');
    });

    test('handles empty string', () {
      expect(normalizeUmlautText(''), '');
    });
  });

  group('stripControlBlocks', () {
    test('removes skill blocks', () {
      final text = 'Hallo ```skill\n{"action":"test"}\n``` Welt';
      expect(stripControlBlocks(text), 'Hallo  Welt');
    });

    test('removes BUTTONS inline', () {
      final text = 'Text BUTTONS: {"buttons":[]}';
      expect(stripControlBlocks(text), 'Text');
    });
  });

  group('sanitizeAssistantText', () {
    test('removes markdown formatting', () {
      expect(sanitizeAssistantText('**bold** text'), 'bold text');
    });

    test('strips trailing braces from partial JSON', () {
      final result = sanitizeAssistantText('Text {"key":"value"}');
      expect(result, contains('Text'));
    });
  });

  group('intent detection', () {
    test('looksLikeUploadPrompt', () {
      expect(looksLikeUploadPrompt('Foto hochladen'), isTrue);
      expect(looksLikeUploadPrompt('Bild senden'), isTrue);
      expect(looksLikeUploadPrompt('Hallo Welt'), isFalse);
    });

    test('looksLikeVisualEditPrompt', () {
      expect(looksLikeVisualEditPrompt('Wände einfärben'), isTrue);
      expect(looksLikeVisualEditPrompt('virtuell gestalten'), isTrue);
      expect(looksLikeVisualEditPrompt('Hallo'), isFalse);
    });

    test('looksLikeMeasurementRequest', () {
      expect(looksLikeMeasurementRequest('Wieviel Farbe brauche ich?'), isTrue);
      expect(looksLikeMeasurementRequest('20 qm Wohnzimmer'), isTrue);
      expect(looksLikeMeasurementRequest('Hallo Welt'), isFalse);
    });

    test('looksLikeCartPrompt', () {
      expect(looksLikeCartPrompt('In den Warenkorb'), isTrue);
      expect(looksLikeCartPrompt('Zur Kasse'), isTrue);
      expect(looksLikeCartPrompt('Hallo'), isFalse);
    });

    test('isCheckoutLabel', () {
      expect(isCheckoutLabel('Zum Warenkorb'), isTrue);
      expect(isCheckoutLabel('Weiter'), isFalse);
    });

    test('looksLikeResultRequest', () {
      expect(looksLikeResultRequest('Ergebnis anzeigen'), isTrue);
      expect(looksLikeResultRequest('Vorher/Nachher'), isTrue);
      expect(looksLikeResultRequest('Hallo'), isFalse);
    });

    test('looksLikeEditCompletion', () {
      expect(looksLikeEditCompletion('Bild wurde bearbeitet'), isTrue);
      expect(looksLikeEditCompletion('Rendering läuft'), isFalse);
    });

    test('isVirtualRoomRequestText', () {
      expect(isVirtualRoomRequestText('Wände virtuell gestalten'), isTrue);
      expect(isVirtualRoomRequestText('Raumfoto bearbeiten'), isTrue);
    });

    test('isRoomFlowContext', () {
      expect(isRoomFlowContext('Wände rendern'), isTrue);
      expect(isRoomFlowContext('Hallo'), isFalse);
    });
  });

  group('image format detection', () {
    test('looksLikePng detects PNG header', () {
      final pngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      ]);
      expect(looksLikePng(pngBytes), isTrue);
    });

    test('looksLikePng rejects non-PNG', () {
      expect(looksLikePng(Uint8List.fromList([0xFF, 0xD8])), isFalse);
    });

    test('looksLikeJpeg detects JPEG header', () {
      expect(looksLikeJpeg(Uint8List.fromList([0xFF, 0xD8])), isTrue);
    });

    test('looksLikeJpeg rejects non-JPEG', () {
      expect(looksLikeJpeg(Uint8List.fromList([0x89, 0x50])), isFalse);
    });

    test('looksLikePng rejects too short', () {
      expect(looksLikePng(Uint8List.fromList([0x89])), isFalse);
    });
  });

  group('isRemotePath', () {
    test('detects http', () {
      expect(isRemotePath('http://example.com'), isTrue);
    });

    test('detects https', () {
      expect(isRemotePath('https://example.com'), isTrue);
    });

    test('rejects local path', () {
      expect(isRemotePath('/tmp/file.png'), isFalse);
    });
  });

  group('isValidImageUrlForChat', () {
    test('accepts remote URL', () {
      expect(isValidImageUrlForChat('https://example.com/img.png'), isTrue);
    });

    test('rejects empty data URL', () {
      expect(isValidImageUrlForChat('data:image/png;base64,'), isFalse);
    });

    test('rejects non-image data URL', () {
      expect(isValidImageUrlForChat('data:text/plain;base64,aGVsbG8='), isFalse);
    });
  });
}
