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

  final double screenPadding;
  final double screenPaddingSm;
  final double contentMaxWidth;
  final double gapXs;
  final double gapSm;
  final double gapMd;
  final double gapLg;
  final double segmentedTabHeight;

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
    required this.screenPadding,
    required this.screenPaddingSm,
    required this.contentMaxWidth,
    required this.gapXs,
    required this.gapSm,
    required this.gapMd,
    required this.gapLg,
    required this.segmentedTabHeight,
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
    screenPadding: 32,
    screenPaddingSm: 16,
    contentMaxWidth: 720,
    gapXs: 6,
    gapSm: 8,
    gapMd: 12,
    gapLg: 24,
    segmentedTabHeight: 46,
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
    double? screenPadding,
    double? screenPaddingSm,
    double? contentMaxWidth,
    double? gapXs,
    double? gapSm,
    double? gapMd,
    double? gapLg,
    double? segmentedTabHeight,
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
      screenPadding: screenPadding ?? this.screenPadding,
      screenPaddingSm: screenPaddingSm ?? this.screenPaddingSm,
      contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
      gapXs: gapXs ?? this.gapXs,
      gapSm: gapSm ?? this.gapSm,
      gapMd: gapMd ?? this.gapMd,
      gapLg: gapLg ?? this.gapLg,
      segmentedTabHeight: segmentedTabHeight ?? this.segmentedTabHeight,
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
      screenPadding:
          lerpDouble(screenPadding, other.screenPadding, t) ?? screenPadding,
      screenPaddingSm: lerpDouble(
            screenPaddingSm,
            other.screenPaddingSm,
            t,
          ) ??
          screenPaddingSm,
      contentMaxWidth: lerpDouble(contentMaxWidth, other.contentMaxWidth, t) ??
          contentMaxWidth,
      gapXs: lerpDouble(gapXs, other.gapXs, t) ?? gapXs,
      gapSm: lerpDouble(gapSm, other.gapSm, t) ?? gapSm,
      gapMd: lerpDouble(gapMd, other.gapMd, t) ?? gapMd,
      gapLg: lerpDouble(gapLg, other.gapLg, t) ?? gapLg,
      segmentedTabHeight:
          lerpDouble(segmentedTabHeight, other.segmentedTabHeight, t) ??
              segmentedTabHeight,
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
        fontWeight: FontWeight.w700,
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
    final outlineColor = primary.withOpacity(0.35);
    final outlineColorSoft = primary.withOpacity(0.2);

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

    final buttonTextStyle =
        textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700) ??
        const TextStyle(fontWeight: FontWeight.w700);

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
          textStyle: buttonTextStyle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: buttonTextStyle),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: buttonTextStyle,
          side: BorderSide(color: outlineColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(textStyle: buttonTextStyle),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: MaterialStatePropertyAll(buttonTextStyle),
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

      cardTheme: CardThemeData(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: outlineColorSoft, width: 1.2),
        ),
        elevation: 0,
      ),

      // Textfelder
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(
            color: outlineColorSoft,
            width: 1.1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(
            color: outlineColorSoft,
            width: 1.1,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(
            color: outlineColorSoft,
            width: 1.1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(
            color: primary,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.4,
          ),
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

class ThermoloxPagePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool center;
  final double? maxWidth;

  const ThermoloxPagePadding({
    super.key,
    required this.child,
    this.padding,
    this.center = true,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.thermoloxTokens;
    final resolvedPadding =
        padding ?? EdgeInsets.symmetric(horizontal: tokens.screenPadding);
    final resolvedMaxWidth = maxWidth ?? tokens.contentMaxWidth;

    Widget content = Padding(
      padding: resolvedPadding,
      child: child,
    );

    content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
      child: content,
    );

    if (center) {
      content = Center(child: content);
    }

    return content;
  }
}

class ThermoloxScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool safeArea;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;
  final bool centerBody;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  const ThermoloxScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.safeArea = false,
    this.padding,
    this.maxWidth,
    this.centerBody = true,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ThermoloxPagePadding(
      child: body,
      padding: padding,
      maxWidth: maxWidth,
      center: centerBody,
    );

    if (safeArea) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      appBar: appBar,
      body: content,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );
  }
}
