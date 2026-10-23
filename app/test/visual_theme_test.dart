import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/theme/ruhamaa_theme.dart';

void main() {
  test('visual system uses the bundled Arabic family and flat bordered cards', () {
    final theme = RuhamaaTheme.light();
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Tajawal');
    expect(theme.cardTheme.color, Colors.white);
    expect(theme.cardTheme.elevation, 0);
    final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(24));
    expect(shape.side.color, RuhamaaColors.cardBorder);
  });

  test('pages use the warm community background', () {
    final theme = RuhamaaTheme.light();
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFBF8F1));
    expect(RuhamaaColors.text, const Color(0xFF143B42));
    expect(RuhamaaColors.textMuted, const Color(0xFF55686C));
    expect(RuhamaaColors.primary, const Color(0xFF226B5E));
    expect(RuhamaaColors.warmGold, const Color(0xFFD7A24B));
    expect(RuhamaaColors.goldDark, const Color(0xFF8C5B0E));
  });

  test('navigation differentiates selected items without a heavy pill', () {
    final theme = RuhamaaTheme.light().navigationBarTheme;
    final selected = theme.iconTheme!.resolve({WidgetState.selected});
    final idle = theme.iconTheme!.resolve({});
    expect(selected?.color, RuhamaaColors.primary);
    expect(idle?.color, RuhamaaColors.textMuted);
    expect(theme.indicatorColor, Colors.transparent);
  });

  test('hero and page gradients retain the Ataa green identity', () {
    expect(RuhamaaColors.heroGradient.colors.length, 3);
    expect(RuhamaaColors.pageGradient.colors.length, 3);
    expect(RuhamaaColors.heroGradient.colors.last, const Color(0xFF174D5A));
  });
}
