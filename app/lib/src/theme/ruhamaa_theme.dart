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
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: const _RuhamaaBrandPainter()),
    );
  }
}

class _RuhamaaBrandPainter extends CustomPainter {
  const _RuhamaaBrandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final green = Paint()
      ..color = RuhamaaColors.primary
      ..style = PaintingStyle.fill;
    final gold = Paint()
      ..color = RuhamaaColors.warmGold
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.34, h * 0.22), w * 0.105, green);
    canvas.drawCircle(Offset(w * 0.69, h * 0.28), w * 0.085, gold);

    final left = Path()
      ..moveTo(w * 0.33, h * 0.36)
      ..cubicTo(w * 0.17, h * 0.40, w * 0.14, h * 0.62, w * 0.50, h * 0.88)
      ..cubicTo(w * 0.46, h * 0.70, w * 0.48, h * 0.50, w * 0.33, h * 0.36)
      ..close();
    canvas.drawPath(left, green);

    final right = Path()
      ..moveTo(w * 0.68, h * 0.39)
      ..cubicTo(w * 0.84, h * 0.38, w * 0.92, h * 0.53, w * 0.81, h * 0.67)
      ..cubicTo(w * 0.72, h * 0.78, w * 0.61, h * 0.84, w * 0.50, h * 0.90)
      ..cubicTo(w * 0.56, h * 0.72, w * 0.56, h * 0.52, w * 0.68, h * 0.39)
      ..close();
    canvas.drawPath(right, gold);

    final embrace = Paint()
      ..color = RuhamaaColors.warmSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;
    final arc = Path()
      ..moveTo(w * 0.42, h * 0.50)
      ..quadraticBezierTo(w * 0.53, h * 0.59, w * 0.61, h * 0.49);
    canvas.drawPath(arc, embrace);
  }

  @override
  bool shouldRepaint(covariant _RuhamaaBrandPainter oldDelegate) => false;
}
