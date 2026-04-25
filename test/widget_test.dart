// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crash_pad/main.dart';

void main() {
  testWidgets('renders the login surface by default',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Flight crew email'), findsOneWidget);
    expect(find.text('Forgot access code?'), findsOneWidget);
  });

  testWidgets('owner can sign in and reach marketplace shell',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Flight crew email'),
      'owner@crashpads.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Passcode'),
      'owner123',
    );
    await tester.tap(find.text('Sign in securely'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    expect(
      find.text('Book trusted crashpads built for crew rest.'),
      findsOneWidget,
    );
    expect(find.text('Management dashboard'), findsWidgets);
  });
}
