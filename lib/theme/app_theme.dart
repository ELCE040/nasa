import 'package:flutter/material.dart';

/// NAYSA visual identity - Clean, modern dark athletic & scouting theme.
/// Deep Navy (#0D1623), Card Navy (#131F30), Crimson Red (#C41E3A), Gold (#F5C842).
class NasaColors {
  // Brand Identity (User Requested Exact Hex Codes)
  static const navy = Color(0xFF0D1623); // The Canvas: Deep Navy (#0d1623)
  static const navyDark = Color(0xFF070C14); // Deepest Background
  static const navyLight = Color(0xFF1E293B); // Surface Highlight
  static const crimson = Color(0xFFC41E3A); // Crimson Red (#c41e3a)
  static const crimsonLight = Color(0xFF3B121A);
  static const gold = Color(0xFFF5C842); // Athletic Gold (#f5c842)
  static const goldLight = Color(0xFF2C2411);
  static const goldAccent = Color(0xFFF5C842);
  static const blue = Color(0xFF3B82F6); // Electric Blue Accent
  static const green = Color(0xFF10B981); // Emerald Green

  // Clean Dark Surfaces
  static const bgLight = Color(0xFF0D1623); // Main Canvas Background (#0d1623)
  static const bgCard =
      Color(0xFF131F30); // Slightly Lighter Navy Cards (#131f30)
  static const bgCardMuted = Color(0xFF1A2638); // Surface Tint
  static const bgCardHover = Color(0xFF1E2D42);
  static const bgNav = Color(0xFF0D1623); // Bottom Nav & AppBar

  // High-Contrast Typography
  static const textDark = Colors.white; // Headings / Pure White
  static const textMain = Color(0xFFF1F5F9); // Body Text (Crisp Off-White)
  static const textMuted = Color(0xFF94A3B8); // Secondary / Subtitles
  static const textLight = Color(0xFF64748B); // Muted notes

  // Clean Borders & Dividers
  static const border = Color(0xFF1E2D42); // Card & Input Borders
  static const borderSubtle = Color(0xFF182232);

  // Semantics & Backwards-compatible aliases
  static const pitch = crimson;
  static const pitchDark = navy;
  static const pitchLight = crimsonLight;
  static const red = crimson;
  static const redLight = crimsonLight;
  static const white = Color(0xFFFFFFFF);
  static const sun = gold;
  static const earth = crimson;
  static const ink = textDark;
  static const chalk = bgLight;
  static const slate = textMuted;
  static const line = border;
  static const cardDark = bgCard;
  static const cardSurface = bgCard;
  static const bgDark = bgLight;
  static const bgNavy = navy;
}

class NasaTheme {
  static ThemeData theme({Color? primary, Color? secondary}) {
    final base = ThemeData.dark(useMaterial3: true);
    final primaryColor = primary ?? NasaColors.crimson;
    final secondaryColor = secondary ?? NasaColors.gold;

    return base.copyWith(
      scaffoldBackgroundColor: NasaColors.bgLight,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: secondaryColor,
        onSecondary: Colors.black,
        tertiary: NasaColors.blue,
        surface: NasaColors.bgCard,
        onSurface: Colors.white,
        error: primaryColor,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontWeight: FontWeight.w900,
          color: NasaColors.textDark,
          letterSpacing: -0.5,
        ),
        headlineMedium: const TextStyle(
          fontWeight: FontWeight.w900,
          color: NasaColors.textDark,
          letterSpacing: -0.3,
        ),
        headlineSmall: const TextStyle(
          fontWeight: FontWeight.w800,
          color: NasaColors.textDark,
          letterSpacing: -0.2,
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w800,
          color: NasaColors.textDark,
          fontSize: 18,
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          color: NasaColors.textDark,
          fontSize: 15,
        ),
        titleSmall: const TextStyle(
          fontWeight: FontWeight.w700,
          color: NasaColors.textMain,
          fontSize: 13,
        ),
        bodyLarge: const TextStyle(
          color: NasaColors.textMain,
          fontSize: 15,
          height: 1.4,
        ),
        bodyMedium: const TextStyle(
          color: NasaColors.textMain,
          fontSize: 13.5,
          height: 1.4,
        ),
        bodySmall: const TextStyle(
          color: NasaColors.textMuted,
          fontSize: 12,
          height: 1.3,
        ),
        labelLarge: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: NasaColors.bgCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: NasaColors.border, width: 1),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: NasaColors.bgCardMuted,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: NasaColors.textMain,
        ),
        side: const BorderSide(color: NasaColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: NasaColors.bgCard,
        hintStyle: const TextStyle(color: NasaColors.textLight),
        labelStyle: const TextStyle(color: NasaColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: NasaColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: NasaColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor, width: 1.6),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: NasaColors.navy,
        selectedItemColor: primaryColor,
        unselectedItemColor: NasaColors.textMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: NasaColors.border, space: 1),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: NasaColors.textMuted,
        indicatorColor: primaryColor,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: NasaColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: NasaColors.border),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
        contentTextStyle: const TextStyle(
          color: NasaColors.textMain,
          fontSize: 14,
        ),
      ),
    );
  }
}
