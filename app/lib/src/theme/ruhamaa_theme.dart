import 'package:flutter/material.dart';

abstract final class RuhamaaColors {
  static const primary = Color(0xFF226B5E);
  static const primaryDark = Color(0xFF174D45);
  static const primaryBright = Color(0xFF0E9C82);
  static const primaryGlow = Color(0xFF35B99F);
  static const softGreen = Color(0xFFE8F2EF);
  static const warmGold = Color(0xFFD7A24B);
  static const vividGold = Color(0xFFFFAB16);
  static const warmGoldSoft = Color(0xFFFFF3DA);
  static const rose = Color(0xFFF0447B);
  static const blue = Color(0xFF168EB5);
  static const warmSurface = Color(0xFFFFFDF8);
  static const background = Color(0xFFF1F8F7);
  static const text = Color(0xFF143B42);
  static const textMuted = Color(0xFF64777B);
  static const border = Color(0xFFDCEBE8);
  static const success = Color(0xFF2F7D67);

  static const heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF0CA18D), Color(0xFF116D76), Color(0xFF174D5A)],
  );

  static const pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8F8F5), Color(0xFFF5FAF9), Color(0xFFF1F8F7)],
  );
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
      fontFamily: 'Tajawal',
      fontFamilyFallback: const ['Arial', 'sans-serif'],
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: 'Tajawal',
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
        color: Colors.white,
        elevation: 5,
        shadowColor: RuhamaaColors.primaryDark.withValues(alpha: 0.12),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: RuhamaaColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          elevation: 2,
          shadowColor: RuhamaaColors.primary.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: RuhamaaColors.primary,
          side: const BorderSide(color: RuhamaaColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: RuhamaaColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: RuhamaaColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: RuhamaaColors.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: RuhamaaColors.warmSurface,
        elevation: 10,
        height: 76,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? RuhamaaColors.primaryBright : RuhamaaColors.textMuted,
          size: states.contains(WidgetState.selected) ? 29 : 27,
        )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          color: states.contains(WidgetState.selected) ? RuhamaaColors.primaryBright : RuhamaaColors.textMuted,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w700,
        )),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: RuhamaaColors.primaryBright,
        unselectedLabelColor: RuhamaaColors.textMuted,
        indicatorColor: RuhamaaColors.primaryBright,
        dividerColor: RuhamaaColors.border,
        labelStyle: TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: RuhamaaColors.primaryBright,
        linearTrackColor: RuhamaaColors.border,
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
    // Shared geometry with site/assets/ataa-mark.svg and ataa_launcher.xml.
    canvas.save();
    canvas.scale(size.width / 108, size.height / 108);
    final green = Paint()..color = RuhamaaColors.primary;
    final gold = Paint()..color = RuhamaaColors.warmGold;
    canvas.drawCircle(const Offset(34, 26), 10, green);
    canvas.drawCircle(const Offset(74, 26), 10, gold);
    green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(Path()..moveTo(20, 49)..cubicTo(20, 73, 35, 90, 54, 90), green);
    canvas.drawPath(Path()..moveTo(88, 49)..cubicTo(88, 73, 73, 90, 54, 90), gold);
    green.strokeWidth = 8;
    canvas.drawPath(Path()..moveTo(34, 49)..lineTo(54, 64)..lineTo(74, 49), green);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RuhamaaBrandPainter oldDelegate) => false;
}
