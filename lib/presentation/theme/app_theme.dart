import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Material Design 3 (M3) theme configuration and color system
/// for the Local AI Quiz & Reviewer application.
/// Strictly follows the "Calm Cognitive Focus" design guidelines.
class AppTheme {
  /// Centralized Inter Bold typography for the MaQui App Name
  static TextStyle appNameStyle({
    double fontSize = 20,
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
    double letterSpacing = -0.6,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // ---------------------------------------------------------------------------
  // Core Brand Seeds
  // ---------------------------------------------------------------------------
  static const Color primarySeed = Color(0xFF4F46E5);   // Indigo 600 (Intelligence & Focus)
  static const Color secondarySeed = Color(0xFF7C3AED); // Violet 600 (Exam & Creative AI)
  static const Color tertiarySeed = Color(0xFF0D9488);  // Teal 600 (Document Parsing)

  // ---------------------------------------------------------------------------
  // Semantic Educational Tokens
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF16A34A);       // Emerald Green (Correct / High Pass)
  static const Color successDark = Color(0xFF22C55E);
  static const Color warning = Color(0xFFD97706);       // Warm Amber (Medium / 4GB RAM Tier)
  static const Color warningDark = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);         // Crimson Red (Incorrect / Failed)
  static const Color errorDark = Color(0xFFEF4444);
  static const Color info = Color(0xFF2563EB);          // Royal Blue (Study Tips / Guidance)
  static const Color infoDark = Color(0xFF3B82F6);

  // Surface Neutral Tones (Anti-Glare & High Readability)
  static const Color bgLight = Color(0xFFFFFFFF);       // Crisp Pure White Canvas
  static const Color bgDark = Color(0xFF0B0F19);        // Deep Obsidian Slate
  static const Color cardLight = Color(0xFFFFFFFF);     // Pure White Elevated Surface
  static const Color cardDark = Color(0xFF151B2B);      // Obsidian Elevated Surface

  // ---------------------------------------------------------------------------
  // Semantic Color Resolvers
  // ---------------------------------------------------------------------------
  static Color forDifficulty(String difficulty, {bool isDark = false}) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return isDark ? successDark : success;
      case 'hard':
        return isDark ? errorDark : error;
      case 'medium':
      default:
        return isDark ? warningDark : warning;
    }
  }

  static Color forAssessmentMode(bool isExam, {bool isDark = false}) {
    if (isExam) {
      return isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED);
    }
    return isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);
  }

  static Color forPassingScore(int score, {bool isDark = false}) {
    if (score >= 75) {
      return isDark ? successDark : success;
    }
    return isDark ? warningDark : warning;
  }

  static Color forDocType(String type, {bool isDark = false}) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
      case 'pptx':
      case 'ppt':
        return isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
      case 'docx':
      case 'doc':
        return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
      default:
        return isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
    }
  }

  static Color forSrsGrade(int grade) {
    switch (grade) {
      case 1:
        return const Color(0xFFEF4444); // Again (<10m)
      case 2:
        return const Color(0xFFF59E0B); // Hard (1d)
      case 3:
        return const Color(0xFF22C55E); // Good (3d)
      case 4:
        return const Color(0xFF3B82F6); // Easy (7d)
      default:
        return const Color(0xFF94A3B8);
    }
  }

  // ---------------------------------------------------------------------------
  // Light Theme (Clean Pure White Aesthetic)
  // ---------------------------------------------------------------------------
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.light,
    ).copyWith(
      primary: primarySeed,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFEEF2FF), // Indigo 50
      onPrimaryContainer: const Color(0xFF3730A3), // Indigo 800
      secondary: secondarySeed,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFF5F3FF), // Violet 50
      onSecondaryContainer: const Color(0xFF5B21B6), // Violet 800
      tertiary: tertiarySeed,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFF0FDFA), // Teal 50
      onTertiaryContainer: const Color(0xFF115E59), // Teal 800
      surface: const Color(0xFFFFFFFF), // Pure White
      onSurface: const Color(0xFF0F172A), // Slate 900
      onSurfaceVariant: const Color(0xFF475569), // Slate 600
      surfaceContainerLowest: const Color(0xFFFFFFFF), // Pure White Card
      surfaceContainerLow: const Color(0xFFF8FAFC), // Slate 50
      surfaceContainer: const Color(0xFFF1F5F9), // Slate 100
      surfaceContainerHigh: const Color(0xFFE2E8F0), // Slate 200
      surfaceContainerHighest: const Color(0xFFCBD5E1), // Slate 300
      outline: const Color(0xFF94A3B8), // Slate 400
      outlineVariant: const Color(0xFFE2E8F0), // Slate 200 (crisp card border)
      error: error,
      errorContainer: const Color(0xFFFEF2F2), // Red 50
      onErrorContainer: const Color(0xFF991B1B), // Red 800
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFFFFFFF), // Pure White background
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actionsIconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: GoogleFonts.inter(
          color: const Color(0xFF0F172A),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primarySeed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primarySeed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primarySeed, width: 2),
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primarySeed,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFEEF2FF),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primarySeed);
          }
          return const IconThemeData(color: Color(0xFF64748B));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: primarySeed,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          );
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dark Theme
  // ---------------------------------------------------------------------------
  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF6366F1),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF232742),
      onPrimaryContainer: const Color(0xFFC7D2FE),
      secondary: const Color(0xFF8B5CF6),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFF2D234A),
      onSecondaryContainer: const Color(0xFFDDD6FE),
      tertiary: const Color(0xFF14B8A6),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFF133535),
      onTertiaryContainer: const Color(0xFF99F6E4),
      surface: bgDark,
      onSurface: const Color(0xFFF8FAFC),
      surfaceContainerLowest: const Color(0xFF080D1A),
      surfaceContainerLow: const Color(0xFF101524),
      surfaceContainer: cardDark,
      surfaceContainerHigh: const Color(0xFF222B3F),
      surfaceContainerHighest: const Color(0xFF334155),
      outline: const Color(0xFF64748B),
      outlineVariant: const Color(0x28FFFFFF),
      error: errorDark,
      errorContainer: const Color(0xFF451A1A),
      onErrorContainer: const Color(0xFFFECACA),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: const Color(0xFFF8FAFC),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide(color: colorScheme.outlineVariant),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
