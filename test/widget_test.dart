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

  testWidgets('owner can sign in and land on management',
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

    expect(find.text('Manage beds, guests, charges, and payouts.'),
        findsOneWidget);
    expect(find.text('Management command center'), findsOneWidget);
  });

  testWidgets('owner workflow tiles show actionable empty states',
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

    await tester.ensureVisible(find.text('Checkout charges'));
    await tester.tap(find.text('Checkout charges'));
    await tester.pumpAndSettle();
    expect(find.text('No checked-in stays'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Manual assignment'));
    await tester.tap(find.text('Manual assignment'));
    await tester.pumpAndSettle();
    expect(find.text('No stays to assign'), findsOneWidget);
  });

  testWidgets('guest can sign in and submit home search to find',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Flight crew email'),
      'crew@crashpads.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Passcode'),
      'flysafe',
    );
    await tester.tap(find.text('Sign in securely'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    expect(
      find.text('Find verified crashpads near your airport.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Search city, airport, amenity'),
      'SEA',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Find a crashpad'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Search listings'), findsOneWidget);
  });
}
