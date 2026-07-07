import 'package:flutter/material.dart';

/// Nasa Sport visual identity.
///
/// Red and white keep the prototype energetic, direct, and easy to scan,
/// with muted ink/slate values for the data-heavy football views.
class NasaColors {
  static const pitch = Color(0xFFC8102E); // primary red
  static const pitchDark = Color(0xFF8F1023);
  static const sun = Color(0xFFFFCDD5); // soft red accent
  static const earth = Color(0xFFE53935); // live / alerts
  static const ink = Color(0xFF12181A); // near-black text
  static const chalk = Color(0xFFFFF7F8); // white with a red tint
  static const slate = Color(0xFF5C6B66); // muted secondary text
  static const line = Color(0xFFF0D4D9); // hairline / divider on chalk
  static const cardDark = Color(0xFF3A1018);
}

class NasaTheme {
  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: NasaColors.pitch,
        primary: NasaColors.pitch,
        secondary: NasaColors.pitchDark,
        error: NasaColors.earth,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: NasaColors.chalk,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarThemeData(
        backgroundColor: NasaColors.pitch,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(
          fontWeight: FontWeight.w800,
          color: NasaColors.ink,
          letterSpacing: -0.3,
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w800,
          color: NasaColors.ink,
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          color: NasaColors.ink,
        ),
        bodyMedium: const TextStyle(color: NasaColors.ink, height: 1.35),
        bodySmall: const TextStyle(color: NasaColors.slate, height: 1.3),
        labelLarge: const TextStyle(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: NasaColors.line),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: NasaColors.chalk,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: NasaColors.ink,
        ),
        side: const BorderSide(color: NasaColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NasaColors.pitch,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NasaColors.pitch,
          side: const BorderSide(color: NasaColors.pitch),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NasaColors.pitch,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NasaColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NasaColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NasaColors.pitch, width: 1.6),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: NasaColors.pitch,
        unselectedItemColor: NasaColors.slate,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(color: NasaColors.line, space: 1),
      tabBarTheme: const TabBarThemeData(
        labelColor: NasaColors.pitch,
        unselectedLabelColor: NasaColors.slate,
        indicatorColor: NasaColors.pitch,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
