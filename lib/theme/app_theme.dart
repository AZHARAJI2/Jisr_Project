import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color background = Color(0xFF0A0E21);
  static const Color surface = Color(0xFF1D1E33);
  static const Color primaryEmerald = Color(0xFF00FFA3);
  static const Color primaryBlue = Color(0xFF00A3FF);
  static const Color accentPurple = Color(0xFFBF00FF);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryEmerald, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    primaryColor: primaryEmerald,
    hintColor: primaryBlue,
    textTheme: GoogleFonts.tajawalTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.tajawal(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.tajawal(
        fontSize: 16,
        color: textPrimary,
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: primaryEmerald,
      secondary: primaryBlue,
      surface: surface,
      background: background,
    ),
  );
}
