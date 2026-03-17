// lib/utils/format_price.dart

/// Formatiert einen numerischen Preis immer als "1.234,50 €"
String formatPrice(num value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final decPart = parts[1];

  // Insert thousand separators (dots) from the right
  final buf = StringBuffer();
  final start = intPart.startsWith('-') ? 1 : 0;
  final digits = intPart.substring(start);
  for (var i = 0; i < digits.length; i++) {
    final pos = digits.length - i;
    if (i > 0 && pos % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  final formatted = (start == 1 ? '-' : '') + buf.toString();
  return '$formatted,$decPart \u20AC';
}
