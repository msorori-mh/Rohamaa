import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders Sanad Arabic RTL smoke widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Center(child: Text('سند'))),
        ),
      ),
    );

    expect(find.text('سند'), findsOneWidget);
  });
}
