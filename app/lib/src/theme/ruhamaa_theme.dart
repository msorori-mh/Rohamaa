import 'package:flutter/material.dart';

abstract final class RuhamaaColors {
  static const primary = Color(0xFF226B5E);
  static const primaryDark = Color(0xFF174D45);
  static const softGreen = Color(0xFFE8F2EF);
  static const warmGold = Color(0xFFD7A24B);
  static const warmGoldSoft = Color(0xFFFFF3DA);
  static const warmSurface = Color(0xFFFFFDF8);
  static const background = Color(0xFFF7F8F5);
  static const text = Color(0xFF1C2D29);
  static const textMuted = Color(0xFF61706B);
  static const border = Color(0xFFDDE6E2);
  static const success = Color(0xFF2F7D67);
}

abstract final class RuhamaaTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: RuhamaaColors.primary,
      brightness: Brightness.light,
      primary: RuhamaaColors.primary,
      secondary: RuhamaaColors.warmGold,
      surface: RuhamaaColors.warmSurface,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: RuhamaaColors.background,
      fontFamilyFallback: const ['Arial', 'sans-serif'],
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: RuhamaaColors.text,
        displayColor: RuhamaaColors.text,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: RuhamaaColors.background,
        foregroundColor: RuhamaaColors.primaryDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: RuhamaaColors.warmSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: RuhamaaColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: RuhamaaColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: RuhamaaColors.primary,
          side: const BorderSide(color: RuhamaaColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: RuhamaaColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: RuhamaaColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: RuhamaaColors.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: RuhamaaColors.warmSurface,
        indicatorColor: RuhamaaColors.softGreen,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: RuhamaaColors.softGreen,
        side: const BorderSide(color: RuhamaaColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(color: RuhamaaColors.border),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: RuhamaaColors.primaryDark,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }
}

class RuhamaaBrandMark extends StatelessWidget {
  const RuhamaaBrandMark({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: size * 0.08,
            bottom: size * 0.10,
            child: Icon(
              Icons.eco_rounded,
              size: size * 0.72,
              color: RuhamaaColors.primary,
            ),
          ),
          Positioned(
            left: size * 0.08,
            top: size * 0.05,
            child: Icon(
              Icons.favorite_rounded,
              size: size * 0.52,
              color: RuhamaaColors.warmGold,
            ),
          ),
        ],
      ),
    );
  }
}
