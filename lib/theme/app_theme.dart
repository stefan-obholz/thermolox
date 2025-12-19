// lib/theme/app_theme.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class ThermoloxTokens extends ThemeExtension<ThermoloxTokens> {
  final double radiusXs;
  final double radiusSm;
  final double radiusMd;
  final double radiusCard;
  final double radiusLg;
  final double radiusXl;
  final double radiusSheet;
  final double radiusPill;

  final SweepGradient rainbowRingGradient;
  final Color rainbowRingHaloColor;
  final double rainbowRingHaloBlur;
  final double rainbowRingHaloSpread;
  final double rainbowRingHaloBlurSm;
  final double rainbowRingHaloSpreadSm;

  final Duration ringRotationDuration;
  final Duration ringPulseDuration;
  final Duration bubbleIntroDuration;

  const ThermoloxTokens({
    required this.radiusXs,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusCard,
    required this.radiusLg,
    required this.radiusXl,
    required this.radiusSheet,
    required this.radiusPill,
    required this.rainbowRingGradient,
    required this.rainbowRingHaloColor,
    required this.rainbowRingHaloBlur,
    required this.rainbowRingHaloSpread,
    required this.rainbowRingHaloBlurSm,
    required this.rainbowRingHaloSpreadSm,
    required this.ringRotationDuration,
    required this.ringPulseDuration,
    required this.bubbleIntroDuration,
  });

  static const SweepGradient _rainbowRingGradient = SweepGradient(
    colors: [
      Color(0xFFFFD54F),
      Color(0xFF66BB6A),
      Color(0xFF42A5F5),
      Color(0xFFAB47BC),
      Color(0xFFFF7043),
      Color(0xFFFFD54F),
    ],
  );

  static const ThermoloxTokens light = ThermoloxTokens(
    radiusXs: 8,
    radiusSm: 12,
    radiusMd: 14,
    radiusCard: 16,
    radiusLg: 18,
    radiusXl: 22,
    radiusSheet: 24,
    radiusPill: 999,
    rainbowRingGradient: _rainbowRingGradient,
    rainbowRingHaloColor: Color(0x80FFFFFF),
    rainbowRingHaloBlur: 24,
    rainbowRingHaloSpread: 6,
    rainbowRingHaloBlurSm: 16,
    rainbowRingHaloSpreadSm: 4,
    ringRotationDuration: Duration(seconds: 10),
    ringPulseDuration: Duration(milliseconds: 1600),
    bubbleIntroDuration: Duration(milliseconds: 220),
  );

  @override
  ThermoloxTokens copyWith({
    double? radiusXs,
    double? radiusSm,
    double? radiusMd,
    double? radiusCard,
    double? radiusLg,
    double? radiusXl,
    double? radiusSheet,
    double? radiusPill,
    SweepGradient? rainbowRingGradient,
    Color? rainbowRingHaloColor,
    double? rainbowRingHaloBlur,
    double? rainbowRingHaloSpread,
    double? rainbowRingHaloBlurSm,
    double? rainbowRingHaloSpreadSm,
    Duration? ringRotationDuration,
    Duration? ringPulseDuration,
    Duration? bubbleIntroDuration,
  }) {
    return ThermoloxTokens(
      radiusXs: radiusXs ?? this.radiusXs,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusSheet: radiusSheet ?? this.radiusSheet,
      radiusPill: radiusPill ?? this.radiusPill,
      rainbowRingGradient: rainbowRingGradient ?? this.rainbowRingGradient,
      rainbowRingHaloColor: rainbowRingHaloColor ?? this.rainbowRingHaloColor,
      rainbowRingHaloBlur: rainbowRingHaloBlur ?? this.rainbowRingHaloBlur,
      rainbowRingHaloSpread:
          rainbowRingHaloSpread ?? this.rainbowRingHaloSpread,
      rainbowRingHaloBlurSm:
          rainbowRingHaloBlurSm ?? this.rainbowRingHaloBlurSm,
      rainbowRingHaloSpreadSm:
          rainbowRingHaloSpreadSm ?? this.rainbowRingHaloSpreadSm,
      ringRotationDuration: ringRotationDuration ?? this.ringRotationDuration,
      ringPulseDuration: ringPulseDuration ?? this.ringPulseDuration,
      bubbleIntroDuration: bubbleIntroDuration ?? this.bubbleIntroDuration,
    );
  }

  @override
  ThermoloxTokens lerp(ThemeExtension<ThermoloxTokens>? other, double t) {
    if (other is! ThermoloxTokens) return this;
    return ThermoloxTokens(
      radiusXs: lerpDouble(radiusXs, other.radiusXs, t) ?? radiusXs,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t) ?? radiusSm,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t) ?? radiusMd,
      radiusCard: lerpDouble(radiusCard, other.radiusCard, t) ?? radiusCard,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t) ?? radiusLg,
      radiusXl: lerpDouble(radiusXl, other.radiusXl, t) ?? radiusXl,
      radiusSheet:
          lerpDouble(radiusSheet, other.radiusSheet, t) ?? radiusSheet,
      radiusPill: lerpDouble(radiusPill, other.radiusPill, t) ?? radiusPill,
      rainbowRingGradient:
          t < 0.5 ? rainbowRingGradient : other.rainbowRingGradient,
      rainbowRingHaloColor: Color.lerp(
            rainbowRingHaloColor,
            other.rainbowRingHaloColor,
            t,
          ) ??
          rainbowRingHaloColor,
      rainbowRingHaloBlur: lerpDouble(
            rainbowRingHaloBlur,
            other.rainbowRingHaloBlur,
            t,
          ) ??
          rainbowRingHaloBlur,
      rainbowRingHaloSpread: lerpDouble(
            rainbowRingHaloSpread,
            other.rainbowRingHaloSpread,
            t,
          ) ??
          rainbowRingHaloSpread,
      rainbowRingHaloBlurSm: lerpDouble(
            rainbowRingHaloBlurSm,
            other.rainbowRingHaloBlurSm,
            t,
          ) ??
          rainbowRingHaloBlurSm,
      rainbowRingHaloSpreadSm: lerpDouble(
            rainbowRingHaloSpreadSm,
            other.rainbowRingHaloSpreadSm,
            t,
          ) ??
          rainbowRingHaloSpreadSm,
      ringRotationDuration:
          _lerpDuration(ringRotationDuration, other.ringRotationDuration, t),
      ringPulseDuration:
          _lerpDuration(ringPulseDuration, other.ringPulseDuration, t),
      bubbleIntroDuration:
          _lerpDuration(bubbleIntroDuration, other.bubbleIntroDuration, t),
    );
  }

  static Duration _lerpDuration(Duration a, Duration b, double t) {
    final ms = lerpDouble(
          a.inMilliseconds.toDouble(),
          b.inMilliseconds.toDouble(),
          t,
        ) ??
        a.inMilliseconds.toDouble();
    return Duration(milliseconds: ms.round());
  }
}

class AppTheme {
  AppTheme._();

  // ---------- Farben ----------
  static const Color primary = Color(0xFF7B3AED); // Thermolox-Lila
  static const Color accent = Color(0xFFFF6B3D); // CTA / Highlight

  static const Color backgroundLight = Color(0xFFF5F5F8);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  static const Color textLight = Color(0xFF111111);
  static const Color textMutedLight = Color(0xFF7B7B8A);

  static const Color glassLight = Color(0xCCFFFFFF);

  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 32;

  static const String fontFamilyBody = 'Comfortaa';
  static const String fontFamilyHeading = 'DINNextCondensed';

  static TextTheme _buildTextTheme(Color primaryText, Color mutedText) {
    return TextTheme(
      headlineLarge: GoogleFonts.robotoCondensed(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: primaryText,
      ),
      headlineMedium: GoogleFonts.robotoCondensed(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: primaryText,
      ),
      bodyLarge: GoogleFonts.comfortaa(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: primaryText,
      ),
      bodyMedium: GoogleFonts.comfortaa(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: primaryText,
      ),
      bodySmall: GoogleFonts.comfortaa(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: mutedText,
      ),
      labelLarge: GoogleFonts.comfortaa(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: primaryText,
      ),
    );
  }

  /// Einziges öffentliches Theme für die ganze App
  static ThemeData get theme => _buildTheme();

  static ThemeData _buildTheme() {
    const bg = backgroundLight;
    const surface = surfaceLight;
    const text = textLight;
    const textMuted = textMutedLight;

    final textTheme = _buildTextTheme(text, textMuted);

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      error: Colors.redAccent,
      onError: Colors.white,
      background: bg,
      onBackground: text,
      surface: surface,
      onSurface: text,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      fontFamily: fontFamilyBody,
      textTheme: textTheme,
      extensions: const <ThemeExtension<dynamic>>[
        ThermoloxTokens.light,
      ],

      // 🟣 Buttons (THERMOLOX-Lila, weißer Text)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        centerTitle: true,
        titleTextStyle: textTheme.headlineMedium,
      ),

      // Icons
      iconTheme: const IconThemeData(color: textLight),

      // Textfelder
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textMuted),
      ),

      // Snackbars
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontFamily: fontFamilyBody,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),

      dividerColor: Colors.black.withOpacity(0.06),
      splashColor: primary.withOpacity(0.12),
      highlightColor: Colors.transparent,
    );
  }
}

extension ThermoloxThemeX on BuildContext {
  ThermoloxTokens get thermoloxTokens =>
      Theme.of(this).extension<ThermoloxTokens>()!;
}
