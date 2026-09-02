import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Thème visuel de l'application — palette et typographie basées sur le
/// design system "Kinetic Silk" généré avec Google Stitch : indigo/violet
/// sur fond lavande clair, cartes avec ombre douce (pas de bordure dure),
/// typographie Plus Jakarta Sans (titres) + Inter (texte).
class AppTheme {
  AppTheme._();

  // ---------- Couleurs ----------
  static const Color primary = Color(0xFF5343D4);
  static const Color primaryDark = Color(0xFF5645D1);
  static const Color background = Color(0xFFF7F6FD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E1B2E);
  static const Color textSecondary = Color(0xFF6E6B80);
  static const Color divider = Color(0xFFE6E4F2);
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFBA1A1A);

  /// Dégradé signature utilisé pour les éléments d'accent (logo, en-têtes,
  /// bouton principal) — indigo → violet à 135°.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C6FFF), primaryDark],
  );

  // ---------- Rayons ----------
  static const double radiusButton = 16;
  static const double radiusCard = 24;
  static const double radiusIconContainer = 14;

  // ---------- Ombres ----------
  /// Ombre douce et diffuse pour les cartes (niveau 1) — pas de bordure.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0D1E1B2E), blurRadius: 20, offset: Offset(0, 4)),
  ];

  /// Ombre plus marquée pour les éléments flottants (niveau 2).
  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(color: Color(0x1A1E1B2E), blurRadius: 30, offset: Offset(0, 10)),
  ];

  static ThemeData get light {
    final baseTextTheme = GoogleFonts.interTextTheme();
    final headingFont = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: surface,
        error: error,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineMedium: headingFont.headlineMedium?.copyWith(
          color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.4,
        ),
        headlineSmall: headingFont.headlineSmall?.copyWith(
          color: textPrimary, fontWeight: FontWeight.w700,
        ),
        titleLarge: headingFont.titleLarge?.copyWith(
          color: textPrimary, fontWeight: FontWeight.w600,
        ),
        titleMedium: headingFont.titleMedium?.copyWith(
          color: textPrimary, fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: textPrimary),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textSecondary),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
          color: textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: headingFont.titleLarge?.copyWith(
          color: textPrimary, fontWeight: FontWeight.w700,
        ),
      ),
      // Cartes : ombre douce et diffuse (pas de bordure dure), coins très arrondis.
      cardTheme: CardThemeData(
        color: surface,
        elevation: 3,
        shadowColor: textPrimary.withOpacity(0.10),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
          textStyle: headingFont.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.4),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? primary : surface),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? Colors.white : textSecondary),
          side: const WidgetStatePropertyAll(BorderSide(color: divider)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        labelStyle: const TextStyle(color: textSecondary),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: primary,
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
      ),
    );
  }
}
