import 'package:flutter/material.dart';

/// Compact, modern palette â€” not CDN's purple Material shell.
class GuruTheme {
  static const teal = Color(0xFF0B4F5C);
  static const tealDeep = Color(0xFF073840);
  static const sand = Color(0xFFD4A574);
  static const ink = Color(0xFF0E1A1C);
  static const panel = Color(0xFF122428);
  static const line = Color(0x33FFFFFF);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ink,
        colorScheme: const ColorScheme.dark(
          primary: sand,
          secondary: teal,
          surface: panel,
          onPrimary: ink,
          onSurface: Color(0xFFF4F1EA),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: tealDeep,
          foregroundColor: Color(0xFFF4F1EA),
          elevation: 0,
          centerTitle: false,
          toolbarHeight: 44,
        ),
        cardTheme: CardThemeData(
          color: panel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: line),
          ),
        ),
        menuBarTheme: const MenuBarThemeData(
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(tealDeep),
            elevation: WidgetStatePropertyAll(0),
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          titleLarge: TextStyle(fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(height: 1.35),
        ),
      );

  static ThemeData get light => dark;
}
