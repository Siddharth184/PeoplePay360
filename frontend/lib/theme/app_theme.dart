import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Odoo 18 Brand Palette Tokens
  static const Color odooAubergine = Color(0xFF714B67);
  static const Color odooTeal = Color(0xFF017E84);
  static const Color odooTealDark = Color(0xFF00A09D);
  static const Color deepBgLight = Color(0xFFF8FAFC);
  static const Color deepBgDark = Color(0xFF0B0F17);
  
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF161F30);
  
  static const Color surfaceElevatedLight = Color(0xFFF1F5F9);
  static const Color surfaceElevatedDark = Color(0xFF1E293B);

  static const Color emeraldSuccess = Color(0xFF10B981);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color crimsonDanger = Color(0xFFEF4444);

  static const Color odooRed = Color(0xFFEF4444);
  static const Color odooGreen = Color(0xFF10B981);
  static const Color surfaceContainerLow = Color(0xFFF1F5F9);

  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);

  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  static const Color onSurface = Color(0xFF0F172A);
  static const Color onSurfaceVariant = Color(0xFF64748B);

  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: odooAubergine,
    scaffoldBackgroundColor: deepBgLight,
    colorScheme: const ColorScheme.light(
      primary: odooAubergine,
      secondary: odooTeal,
      surface: surfaceLight,
      error: crimsonDanger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimaryLight,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    ).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 28, fontWeight: FontWeight.bold, color: textPrimaryLight, letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 22, fontWeight: FontWeight.w600, color: textPrimaryLight,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 18, fontWeight: FontWeight.w600, color: textPrimaryLight,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.normal, color: textPrimaryLight,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 13, fontWeight: FontWeight.normal, color: textSecondaryLight,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 12, fontWeight: FontWeight.w500, color: textSecondaryLight, letterSpacing: 0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderLight, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: odooAubergine,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surfaceLight,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: const Color(0x1F000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderLight, width: 1),
      ),
      textStyle: GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: textPrimaryLight,
      ),
      iconColor: odooAubergine,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: odooAubergine,
    scaffoldBackgroundColor: deepBgDark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFA27B99),
      secondary: odooTealDark,
      surface: surfaceDark,
      error: crimsonDanger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimaryDark,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    ).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 28, fontWeight: FontWeight.bold, color: textPrimaryDark, letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 22, fontWeight: FontWeight.w600, color: textPrimaryDark,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 18, fontWeight: FontWeight.w600, color: textPrimaryDark,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.normal, color: textPrimaryDark,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 13, fontWeight: FontWeight.normal, color: textSecondaryDark,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 12, fontWeight: FontWeight.w500, color: textSecondaryDark, letterSpacing: 0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderDark, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceDark,
      foregroundColor: textPrimaryDark,
      elevation: 0,
      centerTitle: false,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surfaceDark,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: const Color(0x3D000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderDark, width: 1),
      ),
      textStyle: GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: textPrimaryDark,
      ),
      iconColor: const Color(0xFFA27B99),
    ),
  );
}
