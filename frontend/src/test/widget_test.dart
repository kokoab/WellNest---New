import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/main.dart';
import 'package:my_app/theme/app_theme.dart';

void main() {
  testWidgets('App smoke test: renders MaterialApp without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('App has login route configured', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.routes?.containsKey('/login'), isTrue);
    expect(materialApp.routes?.containsKey('/meal-planner'), isTrue);
  });

  test('dark theme provides text, card, and input colors', () {
    expect(darkTheme.brightness, Brightness.dark);
    expect(darkTheme.textTheme.bodyLarge?.color, isNotNull);
    expect(darkTheme.cardTheme.color, isNotNull);
    expect(darkTheme.inputDecorationTheme.fillColor, isNotNull);
    expect(darkTheme.colorScheme.onSurface, isNot(equals(Colors.transparent)));
  });
}
