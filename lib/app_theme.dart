import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class AppTheme {
  static const Color primary = Color(0xFFFF6B2B);
  static const Color accent = Color(0xFF00C896);
  static const Color info = Color(0xFF2196F3);
  static const Color warning = Color(0xFFFF6B2B);
  static const Color background = Color(0xFFF5F5F5);

  static const Color darkBg = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF141414);
  static const Color darkSurfaceBright = Color(0xFF1E1E1E);
  static const Color darkStroke = Color(0xFF2A2A2A);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Colors.white70;
  static const Color darkTextTertiary = Colors.white54;
  static const Color darkOverlay = Color(0xDD0A0A0A);

  static const String mapStyleNight = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#1a1a2e"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#16213e"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#0f3460"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0f3460"}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#16213e"}]}
  ]
  ''';

  static const String mapStyleDay = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#f5f0e8"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#523735"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#FF6B2B"}]},
    {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#e9bc62"}]},
    {"featureType": "water", "elementType": "geometry.fill", "stylers": [{"color": "#aadaff"}]},
    {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#c5dea8"}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#ede7d8"}]}
  ]
  ''';

  static ThemeData buildTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: background,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static ThemeData buildDarkTheme() {
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      surface: darkSurface,
      onSurface: darkTextPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: darkBg,
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: darkSurfaceBright,
      ),
      cardTheme: CardThemeData(
        color: darkSurfaceBright,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: darkStroke,
        thickness: 1,
      ),
    );
  }
}
