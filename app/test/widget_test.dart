import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders Ruhamaa Arabic RTL smoke widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Center(child: Text('رحماء'))),
        ),
      ),
    );

    expect(find.text('رحماء'), findsOneWidget);
  });
}
