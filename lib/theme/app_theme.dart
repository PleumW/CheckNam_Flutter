import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF4CAF50); // Green for safe
  static const Color dangerColor = Color(0xFFF44336); // Red for danger
  static const Color backgroundColor = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1F1F1F);
  static const Color textPrimaryColor = Colors.white;
  static const Color textSecondaryColor = Colors.white70;

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        error: dangerColor,
        surface: surfaceColor,
      ),
      textTheme: GoogleFonts.promptTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.prompt(color: textPrimaryColor, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.prompt(color: textPrimaryColor, fontWeight: FontWeight.bold),
        bodyLarge: GoogleFonts.prompt(color: textPrimaryColor),
        bodyMedium: GoogleFonts.prompt(color: textSecondaryColor),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondaryColor,
        showUnselectedLabels: true,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
    );
  }
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.grey[100],
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        error: dangerColor,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.promptTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.prompt(color: Colors.black87, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.prompt(color: Colors.black87, fontWeight: FontWeight.bold),
        bodyLarge: GoogleFonts.prompt(color: Colors.black87),
        bodyMedium: GoogleFonts.prompt(color: Colors.black54),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.black54,
        showUnselectedLabels: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
    );
  }
}
