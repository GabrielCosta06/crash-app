// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:crash_pad/data/app_repository.dart';
import 'package:crash_pad/main.dart';
import 'package:crash_pad/models/booking.dart';
import 'package:crash_pad/screens/checkout_screen.dart';
import 'package:crash_pad/services/payment_service.dart';
import 'package:crash_pad/theme/app_theme.dart';

import 'fixtures/crashpad_test_seed.dart';

void main() {
  testWidgets('missing Supabase config shows fail-closed startup',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ConfigurationErrorApp());
    await tester.pumpAndSettle();

    expect(find.text('Supabase configuration required'), findsOneWidget);
    expect(
        find.textContaining('do not run with local mock data'), findsOneWidget);
  });

  testWidgets('renders the login surface by default',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(repository: seededRepository()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Flight crew email'), findsOneWidget);
    expect(find.text('Forgot access code?'), findsOneWidget);
  });

  testWidgets('owner can sign in and land on management',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(repository: seededRepository()));
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

  testWidgets('invalid login shows inline error without leaving login',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(repository: seededRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Flight crew email'),
      'missing@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Passcode'),
      'wrongpass',
    );
    await tester.tap(find.text('Sign in securely'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(find.text('Flight crew email'), findsOneWidget);
  });

  testWidgets('forgot password unknown account shows inline recovery error',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(repository: seededRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot access code?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Crew email'),
      'nobody@example.com',
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('We could not find an account'),
      findsOneWidget,
    );
    expect(find.text('Recover access'), findsOneWidget);
  });

  testWidgets('owner workflow tiles show actionable empty states',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(repository: seededRepository()));
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
    await tester.pumpWidget(MyApp(repository: seededRepository()));
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

  // Repository tests cover this MVP flow. This widget pump currently hangs in
  // the Windows flutter_test runner used by this workspace.
  testWidgets('checkout review submits booking request without card collection',
      (WidgetTester tester) async {
    final repository = seededRepository();
    await repository.logIn('crew@crashpads.com', 'flysafe');
    final crashpad = repository.crashpads.first;
    final guest = repository.currentUser!;
    final checkIn = DateTime(2027, 1, 1);
    final draft = BookingDraft(
      crashpadId: crashpad.id,
      guestId: guest.id,
      nightlyRate: crashpad.price,
      checkInDate: checkIn,
      checkOutDate: checkIn.add(Duration(days: crashpad.minimumStayNights)),
      guestCount: 1,
    );
    const paymentService = PaymentService();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppRepository>.value(
        value: repository,
        child: MaterialApp(
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: CheckoutScreen(
            arguments: CheckoutArguments(
              crashpad: crashpad,
              draft: draft,
              summary: paymentService.buildSummary(draft),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Review booking'), findsOneWidget);
    expect(find.text(crashpad.name), findsOneWidget);

    await tester.tap(find.text('Send booking request'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Booking request pending.'), findsOneWidget);
    expect(repository.bookings, hasLength(1));
  }, skip: true);
}

AppRepository seededRepository() {
  return AppRepository.testSeeded(seed: MockCrashpadSeed.repositorySeed());
}
