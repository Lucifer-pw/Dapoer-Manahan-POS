import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================
// DAPOER MANAHAN - Design System Constants
// ============================================================

class AppColors {
  static bool _isDark = true;
  static void setDarkMode(bool value) => _isDark = value;
  static bool get isDark => _isDark;

  // Primary palette
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryLight = Color(0xFFFF8A5C);
  static const Color primaryDark = Color(0xFFE05A2B);

  // Secondary / Accent
  static const Color secondary = Color(0xFFFFB347);
  static const Color secondaryLight = Color(0xFFFFCC80);

  // Background
  static Color get background => _isDark ? backgroundDark : backgroundLight;
  static Color get surface => _isDark ? surfaceDark : surfaceLight;
  static Color get card => _isDark ? cardDark : cardLight;
  static Color get cardHover => _isDark ? (isDark ? const Color(0xFF2E2E4A) : const Color(0xFFF0F0F0)) : const Color(0xFFF0F0F0);

  // Constants for Theme Definition
  static const Color backgroundDark = Color(0xFF0F0F1A);
  static const Color backgroundLight = Color(0xFFF5F5F7);
  static const Color surfaceDark = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF252540);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryDark = Color(0xFFB0B0C0);
  static const Color textSecondaryLight = Color(0xFF6E6E80);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF66BB6A);
  static const Color error = Color(0xFFEF5350);
  static const Color errorLight = Color(0xFFE57373);
  static const Color warning = Color(0xFFFFC107);
  static const Color warningLight = Color(0xFFFFD54F);
  static const Color info = Color(0xFF42A5F5);

  // Text
  static Color get textPrimary => _isDark ? textPrimaryDark : textPrimaryLight;
  static Color get textSecondary => _isDark ? textSecondaryDark : textSecondaryLight;
  static Color get textHint => _isDark ? const Color(0xFF6E6E80) : const Color(0xFF9E9E9E);

  // Border
  static Color get border => _isDark ? const Color(0xFF333355) : const Color(0xFFE0E0E0);
  static Color get borderLighter => _isDark ? const Color(0xFF444466) : const Color(0xFFEEEEEE);
  static Color get borderLightMode => const Color(0xFFE0E0E0);


  // Gradient
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, _isDark ? const Color(0xFFFF8A5C) : const Color(0xFFE05A2B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get cardGradient => _isDark 
    ? const LinearGradient(
        colors: [Color(0xFF1E1E38), Color(0xFF252545)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      )
    : const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFF0F0F5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get successGradient => const LinearGradient(
    colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        primaryColor: AppColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surfaceDark,
          error: AppColors.error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surfaceDark,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardTheme(
          color: AppColors.cardDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        primaryColor: AppColors.primary,
        dividerColor: AppColors.textSecondaryLight.withOpacity(0.1),
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surfaceLight,
          onSurface: AppColors.textPrimaryLight,
          error: AppColors.error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surfaceLight,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimaryLight,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardTheme(
          color: AppColors.cardLight,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.backgroundLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.primary, width: 1),
          ),
          hintStyle: const TextStyle(color: AppColors.textSecondaryLight),
        ),
        textTheme: GoogleFonts.poppinsTextTheme().copyWith(
          bodyLarge: const TextStyle(color: AppColors.textPrimaryLight),
          bodyMedium: const TextStyle(color: AppColors.textPrimaryLight),
          titleLarge: const TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.bold),
        ),
      );
}

class AppTextStyles {
  static TextStyle get heading1 => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get heading2 => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get heading3 => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get subtitle => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodySecondary => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get price => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      );

  static TextStyle get priceSmall => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      );

  static TextStyle get button => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 100;
}

class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get glow => [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];
}

// Default categories for seeding
class DefaultData {
  static const List<Map<String, dynamic>> categories = [
    {'name': 'Makanan', 'icon': '🍛', 'sortOrder': 0},
    {'name': 'Minuman', 'icon': '🥤', 'sortOrder': 1},
    {'name': 'Dessert', 'icon': '🍰', 'sortOrder': 2},
    {'name': 'Snack', 'icon': '🍟', 'sortOrder': 3},
  ];

  static const int defaultTableCount = 8;
  static const String restaurantName = 'Dapoer Manahan';
  static const String restaurantTagline = 'Point of Sale System';
  static const String restaurantAddress = '';
  static const String restaurantPhone = '';
}
