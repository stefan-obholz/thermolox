import 'dart:convert';
import 'dart:typed_data';

import '../utils/color_utils.dart' show normalizeHex;
export '../utils/color_utils.dart' show normalizeHex;
import 'chat_models.dart';

// ── Regex patterns ──────────────────────────────────────────────────

final RegExp skillBlockRegex = RegExp(
  r'```skill\s+([\s\S]*?)```',
  multiLine: true,
);
final RegExp buttonBlockRegex = RegExp(
  r'```buttons?\s+([\s\S]*?)```',
  multiLine: true,
);
final RegExp inlineButtonsRegex = RegExp(
  r'BUTTONS\s*:\s*(\{[\s\S]*\})',
  multiLine: true,
  caseSensitive: false,
);
final RegExp hexColorRegex = RegExp(
  r'#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b',
);
final RegExp hexColorLooseRegex = RegExp(
  r'(?<![0-9a-fA-F])#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})(?![0-9a-fA-F])',
);

// ── Pure text helpers ───────────────────────────────────────────────

String normalizeMatchText(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9äöüß]+'), ' ')
      .trim();
}

String shorten(String? value, [int max = 200]) {
  if (value == null) return '';
  if (value.length <= max) return value;
  return '${value.substring(0, max)}...';
}

String formatNumber(double value, {int decimals = 1}) {
  return value.toStringAsFixed(decimals).replaceAll('.', ',');
}

String normalizeUmlautText(String text) {
  if (text.isEmpty) return text;
  var result = text;
  const replacements = {
    'Waende': 'Wände',
    'waende': 'wände',
    'Einfaerben': 'Einfärben',
    'einfaerben': 'einfärben',
    'Laeuft': 'Läuft',
    'laeuft': 'läuft',
    'Moechtest': 'Möchtest',
    'moechtest': 'möchtest',
    'Moechte': 'Möchte',
    'moechte': 'möchte',
    'Loeschen': 'Löschen',
    'loeschen': 'löschen',
    'Ueber': 'Über',
    'ueber': 'über',
    'Rueck': 'Rück',
    'rueck': 'rück',
    'Zurueck': 'Zurück',
    'zurueck': 'zurück',
    'Fuer': 'Für',
    'fuer': 'für',
    'Gross': 'Groß',
    'gross': 'groß',
  };
  replacements.forEach((from, to) {
    result = result.replaceAll(RegExp('\\b$from\\b'), to);
  });
  return result;
}

String stripControlBlocks(String text) {
  return text
      .replaceAll(skillBlockRegex, '')
      .replaceAll(buttonBlockRegex, '')
      .replaceAll(inlineButtonsRegex, '')
      .trim();
}

String sanitizeAssistantText(String text) {
  var cleaned = stripControlBlocks(text);
  cleaned = cleaned.replaceAll(RegExp(r'```[a-zA-Z]*'), '');
  cleaned = cleaned.replaceAll('```', '');
  cleaned = cleaned.replaceAll('**', '');
  cleaned = cleaned.replaceAll('__', '');
  cleaned = cleaned.replaceAll(RegExp(r'\n?[}\]]+$'), '').trimRight();
  final trimmed = cleaned.trim();
  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    return '';
  }
  return cleaned.trim();
}

String cleanAssistantDisplayText(String text) {
  var cleaned = text;
  cleaned = cleaned.replaceAll(hexColorRegex, '');
  cleaned = cleaned.replaceAll(RegExp(r'\(\s*\)'), '');
  cleaned = cleaned.replaceAll(RegExp(r'[\-–—:]\s*(?=\n|$)'), '');
  cleaned = cleaned.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  cleaned = cleaned.replaceAll(RegExp(r' *\n *'), '\n');
  cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return cleaned.trim();
}

// ── Intent detection ────────────────────────────────────────────────

bool looksLikeUploadPrompt(String text) {
  final lower = text.toLowerCase();
  final hasAsset = lower.contains('foto') ||
      lower.contains('bild') ||
      lower.contains('grundriss') ||
      lower.contains('skizze');
  final hasAction = lower.contains('hochlad') ||
      lower.contains('upload') ||
      lower.contains('aufnehm') ||
      lower.contains('schick') ||
      lower.contains('sende') ||
      lower.contains('senden') ||
      lower.contains('hinzufueg');
  return hasAsset && hasAction;
}

bool looksLikeResultRequest(String text) {
  final lower = text.toLowerCase();
  return lower.contains('ergebnis') ||
      lower.contains('ansehen') ||
      lower.contains('anzeigen') ||
      lower.contains('zeige') ||
      lower.contains('zeigen') ||
      lower.contains('vorher') ||
      lower.contains('nachher') ||
      lower.contains('vergleich') ||
      lower.contains('before') ||
      lower.contains('after') ||
      lower.contains('sehen');
}

bool looksLikeVisualEditPrompt(String text) {
  final lower = text.toLowerCase();
  return lower.contains('virtuell') ||
      lower.contains('raumgestaltung') ||
      lower.contains('bearbeit') ||
      lower.contains('streichen') ||
      lower.contains('farbe auf') ||
      lower.contains('wand') ||
      lower.contains('anwenden') ||
      lower.contains('raumfoto') ||
      lower.contains('render') ||
      lower.contains('einfaerb') ||
      lower.contains('einfärb');
}

bool isVirtualRoomRequestText(String text) {
  final lower = text.toLowerCase();
  return looksLikeVisualEditPrompt(lower) ||
      lower.contains('raumfoto') ||
      lower.contains('foto fuer') ||
      lower.contains('foto für') ||
      lower.contains('waende') ||
      lower.contains('wände');
}

bool isRoomFlowContext(String text) {
  final lower = text.toLowerCase();
  return lower.contains('waende') ||
      lower.contains('wände') ||
      lower.contains('raumgestaltung') ||
      lower.contains('virtuell') ||
      lower.contains('render');
}

bool looksLikeMeasurementRequest(String text) {
  final lower = text.toLowerCase();
  final hasPaintKeyword = lower.contains('farbe') ||
      lower.contains('farb') ||
      lower.contains('fabe') ||
      lower.contains('anstrich') ||
      lower.contains('streichen') ||
      lower.contains('wand') ||
      lower.contains('wandfarbe') ||
      lower.contains('deckkraft') ||
      lower.contains('reichweite') ||
      lower.contains('ergiebigkeit');
  final hasSealKeyword = lower.contains('thermo-seal') ||
      lower.contains('thermo seal') ||
      lower.contains('fugenband') ||
      lower.contains('abdicht') ||
      lower.contains('dichtband');
  final hasNeedKeyword = RegExp(
    r'\b(wieviel|wie viel|wie viele|brauche|brauch|benoet|benöt|bedarf|verbrauch|'
    r'reicht|ausreichend|genug|liter|l|eimer|dose|packung|rolle|meter)\b',
  ).hasMatch(lower);
  final hasAreaUnit = RegExp(
    r'\b\d+([.,]\d+)?\s*(qm|m2|m²|quadratmeter)\b',
  ).hasMatch(lower);
  final hasDimensionUnit = RegExp(
    r'\b\d+([.,]\d+)?\s*(m|meter)\b',
  ).hasMatch(lower);
  final hasDimensionPattern = RegExp(
    r'\b\d+([.,]\d+)?\s*[x×]\s*\d+([.,]\d+)?\b',
  ).hasMatch(lower);
  final mentionsAmount =
      hasNeedKeyword && (hasPaintKeyword || hasSealKeyword);
  return mentionsAmount ||
      hasAreaUnit ||
      hasDimensionUnit ||
      hasDimensionPattern;
}

bool looksLikeEditCompletion(String text) {
  final lower = text.toLowerCase();
  return lower.contains('bearbeitet') ||
      lower.contains('angewendet') ||
      lower.contains('fertig') ||
      lower.contains('abgeschlossen') ||
      lower.contains('gerendert') ||
      lower.contains('erstellt') ||
      lower.contains('erzeugt');
}

bool looksLikeCartPrompt(String text) {
  final lower = text.toLowerCase();
  return lower.contains('warenkorb') ||
      lower.contains('kasse') ||
      lower.contains('bestellen') ||
      lower.contains('checkout');
}

bool isCheckoutLabel(String label) {
  final lower = label.toLowerCase();
  return lower.contains('warenkorb') ||
      lower.contains('kasse') ||
      lower.contains('checkout');
}

bool isRemotePath(String path) {
  return path.startsWith('http://') || path.startsWith('https://');
}

bool looksLikePng(Uint8List bytes) {
  if (bytes.length < 8) return false;
  return bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A;
}

bool looksLikeJpeg(Uint8List bytes) {
  if (bytes.length < 2) return false;
  return bytes[0] == 0xFF && bytes[1] == 0xD8;
}

bool isValidImageUrlForChat(String url) {
  if (isRemotePath(url)) return true;
  if (!url.startsWith('data:image/')) return false;
  final commaIndex = url.indexOf(',');
  if (commaIndex <= 0) return false;
  final meta = url.substring(0, commaIndex);
  if (!meta.contains('base64')) return false;
  final payload = url.substring(commaIndex + 1).trim();
  if (payload.isEmpty) return false;
  try {
    base64Decode(payload);
    return true;
  } catch (_) {
    return false;
  }
}

// ── Room aliases ────────────────────────────────────────────────────

const Map<String, List<String>> roomAliases = {
  'Wohnzimmer': ['wohnzimmer', 'living', 'livingroom', 'sofa'],
  'Schlafzimmer': ['schlafzimmer', 'bedroom', 'bett'],
  'Küche': ['küche', 'kueche', 'kitchen'],
  'Bad': ['bad', 'badezimmer', 'bath'],
  'Esszimmer': ['esszimmer', 'dining'],
  'Kinderzimmer': ['kinderzimmer', 'kids', 'kind'],
  'Büro': ['büro', 'buero', 'office'],
  'Flur': ['flur', 'diele', 'gang'],
  'Keller': ['keller', 'basement'],
  'Balkon': ['balkon', 'balcony'],
};

// ── Room detection helpers ──────────────────────────────────────────

int? extractOrdinal(String text) {
  final lower = text.toLowerCase();
  const wordOrdinals = <int, List<String>>{
    1: ['erste', 'erster', 'erstes', 'ersten', 'erstem'],
    2: ['zweite', 'zweiter', 'zweites', 'zweiten', 'zweitem'],
    3: ['dritte', 'dritter', 'drittes', 'dritten', 'drittem'],
    4: ['vierte', 'vierter', 'viertes', 'vierten', 'viertem'],
    5: [
      'fünfte', 'fünfter', 'fünftes', 'fünften', 'fünftem',
      'fuenfte', 'fuenfter', 'fuenftes', 'fuenften', 'fuenftem',
    ],
    6: ['sechste', 'sechster', 'sechstes', 'sechsten', 'sechstem'],
    7: ['siebte', 'siebter', 'siebtes', 'siebten', 'siebtem'],
    8: ['achte', 'achter', 'achtes', 'achten', 'achtem'],
    9: ['neunte', 'neunter', 'neuntes', 'neunten', 'neuntem'],
    10: ['zehnte', 'zehnter', 'zehntes', 'zehnten', 'zehntem'],
  };
  for (final entry in wordOrdinals.entries) {
    for (final word in entry.value) {
      if (RegExp('\\b$word\\b').hasMatch(lower)) {
        return entry.key;
      }
    }
  }

  final numericMatch =
      RegExp(r'\b(10|[1-9])\s*(?:te|ter|tes|ten)?\b|\b(10|[1-9])\.\b')
          .firstMatch(lower);
  if (numericMatch != null) {
    final raw = numericMatch.group(1) ?? numericMatch.group(2);
    final value = int.tryParse(raw ?? '');
    if (value != null) return value;
  }

  const cardinals = <String, int>{
    'eins': 1,
    'eine': 1,
    'einen': 1,
    'zwei': 2,
    'drei': 3,
    'vier': 4,
    'fünf': 5,
    'fuenf': 5,
    'sechs': 6,
    'sieben': 7,
    'acht': 8,
    'neun': 9,
    'zehn': 10,
  };
  for (final entry in cardinals.entries) {
    if (RegExp('\\b${entry.key}\\b').hasMatch(lower)) {
      return entry.value;
    }
  }

  return null;
}

int? extractOrdinalNearToken(String text, String token) {
  final idx = text.indexOf(token);
  if (idx < 0) return null;
  final start = (idx - 30).clamp(0, text.length);
  final end = (idx + token.length + 30).clamp(0, text.length);
  final window = text.substring(start, end);
  return extractOrdinal(window);
}

bool hasAlternateRoomKeywordNearToken(String text, String token) {
  final idx = text.indexOf(token);
  if (idx < 0) return false;
  final start = (idx - 30).clamp(0, text.length);
  final end = (idx + token.length + 30).clamp(0, text.length);
  final window = text.substring(start, end);
  final regex = RegExp(
    r'\b(ander(e|er|es|en|em)|weiter(e|er|es|en|em)|zusätzlich|zusatz|noch\s+ein(e|en)?)\b',
  );
  return regex.hasMatch(window);
}

bool hasExistingRoomKeywordNearToken(String text, String token) {
  final idx = text.indexOf(token);
  if (idx < 0) return false;
  final start = (idx - 30).clamp(0, text.length);
  final end = (idx + token.length + 30).clamp(0, text.length);
  final window = text.substring(start, end);
  final regex = RegExp(
    r'\b(bestehend(e|er|es|en|em)?|vorhanden(e|er|es|en|em)?|dies(e|er|es|en|em)?|aktuell(e|er|es|en|em)?|mein(e|er|es|en|em)?|unser(e|er|es|en|em)?)\b',
  );
  return regex.hasMatch(window);
}

bool isRoomWordChar(String char) {
  return RegExp(r'[a-z0-9äöüß-]').hasMatch(char);
}

String? extractRoomWordForToken(String text, String tokenLower) {
  final lower = text.toLowerCase();
  final idx = lower.indexOf(tokenLower);
  if (idx < 0) return null;
  var start = idx;
  while (start > 0 && isRoomWordChar(lower[start - 1])) {
    start -= 1;
  }
  var end = idx + tokenLower.length;
  while (end < lower.length && isRoomWordChar(lower[end])) {
    end += 1;
  }
  final word = text.substring(start, end).trim();
  if (word.isEmpty) return null;
  return word;
}

String formatRoomLabel(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

RoomMention? detectRoomMention(String text) {
  final lower = text.toLowerCase();
  String? bestBase;
  String? bestToken;
  var bestLen = 0;
  for (final entry in roomAliases.entries) {
    for (final token in entry.value) {
      if (!lower.contains(token)) continue;
      if (token.length > bestLen) {
        bestLen = token.length;
        bestBase = entry.key;
        bestToken = token;
      }
    }
  }
  if (bestBase == null || bestToken == null) return null;
  final ordinal = extractOrdinalNearToken(lower, bestToken);
  final wantsAnother =
      hasAlternateRoomKeywordNearToken(lower, bestToken) ||
      (ordinal != null && ordinal > 1);
  final wantsExisting = hasExistingRoomKeywordNearToken(lower, bestToken);
  final rawWord = extractRoomWordForToken(text, bestToken);
  String? customLabel;
  if (rawWord != null) {
    final rawNorm = normalizeMatchText(rawWord);
    final baseNorm = normalizeMatchText(bestBase);
    if (rawNorm.isNotEmpty && rawNorm != baseNorm) {
      customLabel = formatRoomLabel(rawWord);
    }
  }
  final customDiffers = customLabel != null &&
      normalizeMatchText(customLabel) != normalizeMatchText(bestBase);
  return RoomMention(
    base: bestBase,
    token: bestToken,
    ordinal: ordinal,
    wantsAnother: wantsAnother || customDiffers,
    wantsExisting: wantsExisting,
    customLabel: customLabel,
  );
}

String roomLabelFromMention(RoomMention mention) {
  final label = (mention.customLabel ?? mention.base).trim();
  final ord = mention.ordinal;
  if (ord == null) return label;
  if (RegExp(r'\b\d+\b').hasMatch(label)) return label;
  return '$label $ord';
}

// ── Measurement intent helpers ──────────────────────────────────────

bool wantsMeasurementRescan(String text) {
  final lower = text.toLowerCase();
  return lower.contains('neu messen') ||
      lower.contains('neu scannen') ||
      lower.contains('nochmal messen') ||
      lower.contains('erneut messen') ||
      lower.contains('erneut scannen') ||
      lower.contains('messung starten') ||
      lower.contains('scan starten') ||
      lower.contains('messung ändern') ||
      lower.contains('messung aendern') ||
      lower.contains('messung anpassen');
}

bool wantsMeasurementManual(String text) {
  final lower = text.toLowerCase();
  return lower.contains('manuell') ||
      lower.contains('eingeben') ||
      lower.contains('eintragen') ||
      lower.contains('masse') ||
      lower.contains('maße') ||
      lower.contains('laenge') ||
      lower.contains('länge') ||
      lower.contains('breite') ||
      lower.contains('höhe') ||
      lower.contains('flaeche') ||
      lower.contains('fläche') ||
      lower.contains('qm');
}

bool wantsMeasurementCamera(String text) {
  final lower = text.toLowerCase();
  final hasArWord = RegExp(r'\bar\b').hasMatch(lower);
  return lower.contains('kamera') ||
      lower.contains('scan') ||
      lower.contains('scannen') ||
      lower.contains('lidar') ||
      lower.contains('foto') ||
      lower.contains('fotos') ||
      lower.contains('bild') ||
      lower.contains('bilder') ||
      hasArWord;
}

bool isFlowCancelRequest(String lowerText) {
  return lowerText == 'abbrechen' ||
      lowerText == 'nicht jetzt' ||
      lowerText == 'später' ||
      lowerText == 'stop' ||
      lowerText == 'zurück';
}

bool wantsMeasurementCancel(String text) {
  final lower = text.toLowerCase();
  return lower.contains('abbrechen') ||
      lower.contains('später') ||
      lower.contains('nicht jetzt');
}

bool wantsMeasurementAutomatic(String text) {
  final lower = text.toLowerCase();
  return lower.contains('automatisch') ||
      lower.contains('auto') ||
      lower.contains('messung starten') ||
      wantsMeasurementCamera(text);
}

// ── Color helpers ───────────────────────────────────────────────────

int colorFromHexValue(String hex) {
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 3) {
    h = h.split('').map((c) => '$c$c').join();
  }
  if (h.length < 6) {
    h = h.padRight(6, '0');
  }
  final val = int.tryParse(h.substring(0, 6), radix: 16) ?? 0x777777;
  return 0xFF000000 | val;
}

List<String> extractHexColors(String text) {
  final matches = hexColorRegex.allMatches(text);
  if (matches.isEmpty) return const [];
  final seen = <String>{};
  final result = <String>[];
  for (final match in matches) {
    final raw = match.group(0);
    if (raw == null) continue;
    final normalized = normalizeHex(raw);
    if (seen.add(normalized)) {
      result.add(normalized);
    }
  }
  return result;
}

List<String> extractHexColorsLoose(String text) {
  var source = text;
  if (RegExp(r'^[\s#0-9a-fA-F.,-]+$').hasMatch(source)) {
    source = source.replaceAll(RegExp(r'[^0-9a-fA-F#]'), '');
  }
  final matches = hexColorLooseRegex.allMatches(source);
  if (matches.isEmpty) return const [];
  final seen = <String>{};
  final result = <String>[];
  for (final match in matches) {
    final raw = match.group(0);
    if (raw == null) continue;
    final hasHash = raw.startsWith('#');
    final hasDigit = RegExp(r'[0-9]').hasMatch(raw);
    if (!hasDigit && !hasHash) continue;
    final normalized = normalizeHex(raw);
    if (seen.add(normalized)) {
      result.add(normalized);
    }
  }
  return result;
}
