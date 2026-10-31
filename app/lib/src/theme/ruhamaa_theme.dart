import 'package:flutter/material.dart';

abstract final class RuhamaaColors {
  // Warm community palette (approved mockups). Existing names keep working
  // for every screen; the values moved to the warmer base.
  static const primary = Color(0xFF226B5E);
  static const primaryDark = Color(0xFF174D45);
  static const primaryBright = Color(0xFF0E9C82);
  static const primaryGlow = Color(0xFF35B99F);
  static const softGreen = Color(0xFFE8F2EF);
  static const warmGold = Color(0xFFD7A24B);
  static const vividGold = Color(0xFFFFAB16);
  static const warmGoldSoft = Color(0xFFF6E3BC);
  static const rose = Color(0xFFF0447B);
  static const blue = Color(0xFF168EB5);
  static const warmSurface = Color(0xFFFFFDF8);
  static const background = Color(0xFFFBF8F1);
  static const text = Color(0xFF143B42);
  static const textMuted = Color(0xFF55686C);
  static const border = Color(0xFFE4DED1);
  static const success = Color(0xFF2F7D67);

  /// Border of white cards on the warm background.
  static const cardBorder = Color(0xFFE9E3D6);

  /// Border of text fields and unselected choice chips.
  static const inputBorder = Color(0xFFDCD5C6);

  /// Sand panels (privacy note, photo tile icon).
  static const sand = Color(0xFFF1ECE0);

  /// Text on the sand privacy panel.
  static const noteText = Color(0xFF4A3D28);

  /// Body copy on light panels and secondary icons.
  static const bodyMuted = Color(0xFF4A5B5E);
  static const iconMuted = Color(0xFF5E6F72);

  /// Pale green circle behind icons, and the selected green tile.
  static const mint = Color(0xFFEEF5F2);
  static const mintStrong = Color(0xFFE1EFEA);

  /// The request ("ما أحتاجه") flow: dark gold actions and soft gold tiles.
  static const goldDark = Color(0xFF8C5B0E);
  static const goldDeep = Color(0xFF7A5512);
  static const goldInk = Color(0xFF4A3410);
  static const goldTint = Color(0xFFFBF1DE);
  static const goldSelected = Color(0xFFFBEFD6);

  /// Time and skills accent.
  static const sky = Color(0xFF1F6E8C);
  static const skyTint = Color(0xFFE6F0F4);

  /// Unread marker on the bell.
  static const alert = Color(0xFFC0392B);

  /// Ring of a timeline step that has not been reached yet.
  static const stepIdle = Color(0xFFD6CFBF);

  static const heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF0CA18D), Color(0xFF116D76), Color(0xFF174D5A)],
  );

  static const pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF6F1E6), Color(0xFFFBF8F1), Color(0xFFFBF8F1)],
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
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: RuhamaaColors.cardBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          backgroundColor: RuhamaaColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w700),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          foregroundColor: RuhamaaColors.primary,
          side: const BorderSide(color: RuhamaaColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: RuhamaaColors.inputBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: RuhamaaColors.inputBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: RuhamaaColors.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 76,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? RuhamaaColors.primary : RuhamaaColors.textMuted,
          size: 26,
        )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontFamily: 'Tajawal',
          color: states.contains(WidgetState.selected) ? RuhamaaColors.primary : RuhamaaColors.textMuted,
          fontSize: 13,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
        )),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: RuhamaaColors.primary,
        unselectedLabelColor: RuhamaaColors.textMuted,
        indicatorColor: RuhamaaColors.primary,
        dividerColor: RuhamaaColors.border,
        labelStyle: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600),
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
        color: RuhamaaColors.primary,
        linearTrackColor: RuhamaaColors.border,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: RuhamaaColors.softGreen,
        side: const BorderSide(color: RuhamaaColors.inputBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(color: RuhamaaColors.border),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: RuhamaaColors.primaryDark,
        contentTextStyle: TextStyle(fontFamily: 'Tajawal', color: Colors.white),
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
