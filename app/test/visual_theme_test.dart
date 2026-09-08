import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/theme/ruhamaa_theme.dart';

void main() {
  test('visual system uses the bundled Arabic family and elevated soft cards', () {
    final theme = RuhamaaTheme.light();
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Tajawal');
    expect(theme.cardTheme.color, Colors.white);
    expect(theme.cardTheme.elevation, greaterThan(0));
    final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(28));
  });

  test('navigation differentiates selected items without a heavy pill', () {
    final theme = RuhamaaTheme.light().navigationBarTheme;
    final selected = theme.iconTheme!.resolve({WidgetState.selected});
    final idle = theme.iconTheme!.resolve({});
    expect(selected?.color, RuhamaaColors.primaryBright);
    expect(idle?.color, RuhamaaColors.textMuted);
    expect(theme.indicatorColor, Colors.transparent);
  });

  test('hero and page gradients retain the Ruhamaa green identity', () {
    expect(RuhamaaColors.heroGradient.colors.length, 3);
    expect(RuhamaaColors.pageGradient.colors.length, 3);
    expect(RuhamaaColors.heroGradient.colors.last, const Color(0xFF174D5A));
  });
}
