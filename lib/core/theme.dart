// shared theme colors and material styling for whole app
import 'package:flutter/material.dart';

// central brand colors used consistently across all app screens
class CmColors {
  static const primary = Color(0xFF1E3A5F);
  static const primaryDark = Color(0xFF0A1628);
  static const accent = Color(0xFFE8590C);
  static const bg = Color(0xFFF6F7F9);
  static const card = Colors.white;
}

// builds light material theme using coldmount brand primary color
ThemeData coldmountTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: CmColors.primary);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(primary: CmColors.primary),
    scaffoldBackgroundColor: CmColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: CmColors.primary,
      foregroundColor: Colors.white,
    ),
  );
}

// formats number as peso string with comma grouped digits
String peso(num n) {
  final s = n.toStringAsFixed(n is int || n == n.roundToDouble() ? 0 : 2);
  final parts = s.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return parts.length > 1 ? '₱$intPart.${parts[1]}' : '₱$intPart';
}
