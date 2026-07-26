import 'package:flutter/material.dart';

// Jedinstvena paleta boja za cijelu aplikaciju — maslinasto zelena kao
// primarna boja (dugmad, odabrani dan, progress, checkbox) i toplo zlatna
// kao akcent (prsten oko avatara mačke), po uzoru na referentni dizajn.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF325603);
  static const Color primaryDark = Color(0xFF1C3001);
  static const Color primaryLight = Color(0xFF6B8F3A);
  static const Color tint100 = Color(0xFFDCE6C9);
  static const Color tint50 = Color(0xFFEFF3E7);

  static const Color gold = Color(0xFFAD9A68);
  static const Color goldTint = Color(0xFFF0EAD8);

  static const Color background = Color(0xFFF5F5F5);
  static const Color card = Colors.white;
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textMuted = Color(0xFF9B9B9B);
  static const Color cardBorder = Color(0xFFF0F0F0);
}
