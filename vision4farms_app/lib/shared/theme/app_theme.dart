import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Cores principais
  static const Color primary       = Color(0xFF2E7D32);
  static const Color primaryLight  = Color(0xFF4CAF50);
  static const Color primaryDark   = Color(0xFF1B5E20);
  static const Color primaryBg     = Color(0xFFEFF7EF); // fundo verde claro do Figma
  static const Color accent        = Color(0xFFFFA000);
  static const Color error         = Color(0xFFD32F2F);
  static const Color success       = Color(0xFF388E3C);
  static const Color warning       = Color(0xFFF57C00);
  static const Color background    = Color(0xFFEFF7EF); // igual ao primaryBg
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color textPrimary   = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider       = Color(0xFFE0E0E0);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        error: error,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        headlineLarge: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary),
        headlineMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
        headlineSmall: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: textPrimary),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: error,
          side: const BorderSide(color: error),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: Color(0xFFBDBDBD), fontSize: 14),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: divider),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}