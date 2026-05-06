import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Temel smoke — Flutter pompalama', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('ADÜPass test')),
        ),
      ),
    );

    expect(find.text('ADÜPass test'), findsOneWidget);
  });
}
