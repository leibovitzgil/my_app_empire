import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application Theme definition.
class AppTheme {
  /// Returns the light theme.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      textTheme: GoogleFonts.robotoTextTheme(),
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    );
  }

  /// Returns the dark theme.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
    );
  }
}
