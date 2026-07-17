import 'package:flutter/material.dart';

import '../domain/account.dart';

class FluxoraTheme {
  static const seed = Color(0xFF6EE7B7);
  static const ink = Color(0xFF071A17);

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);
  static ThemeData businessDark(BusinessType type) =>
      _build(Brightness.dark, seedColor: _seedForBusiness(type));
  static ThemeData businessLight(BusinessType type) =>
      _build(Brightness.light, seedColor: _seedForBusiness(type));

  static ThemeData _build(Brightness brightness, {Color seedColor = seed}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      surface: brightness == Brightness.dark
          ? const Color(0xFF0C1514)
          : const Color(0xFFF3F8F6),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primaryContainer,
        backgroundColor: scheme.surfaceContainer,
      ),
    );
  }

  static Color _seedForBusiness(BusinessType type) => switch (type) {
    BusinessType.barbershop => const Color(0xFFD1A054),
    BusinessType.beautySalon => seed,
    BusinessType.nailStudio => const Color(0xFFF472B6),
    BusinessType.browAndLashStudio => const Color(0xFFC084FC),
    BusinessType.makeupStudio => const Color(0xFFFB7185),
    BusinessType.spa => const Color(0xFF5EEAD4),
    BusinessType.aestheticClinic => const Color(0xFF38BDF8),
    BusinessType.otherBeauty => const Color(0xFFA7F3D0),
  };
}
