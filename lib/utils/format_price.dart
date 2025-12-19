// lib/utils/format_price.dart

/// Formatiert einen numerischen Preis immer als "9,90 €"
String formatPrice(num value) {
  // 2 Nachkommastellen, Punkt -> Komma, " €" anhängen
  return value.toStringAsFixed(2).replaceAll('.', ',') + ' €';
}
