import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_app_local_ai/main.dart';
import 'package:quiz_app_local_ai/presentation/screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LocalAiQuizApp renders splash screen and navigates to Welcome & Offline Privacy Promise', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const LocalAiQuizApp());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(SplashScreen), findsOneWidget);

    // Complete splash timer (2000ms) and fade transition (1100ms)
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump(const Duration(milliseconds: 1200));

    // Verifies the Welcome & Offline Privacy Promise combined notice appears on launch
    expect(find.text('Welcome & Offline Privacy Promise'), findsOneWidget);

    // Verify checkbox is present
    final checkboxFinder = find.byType(Checkbox);
    expect(checkboxFinder, findsOneWidget);

    // Tap the checkbox to agree
    await tester.tap(checkboxFinder);
    await tester.pump();

    // Tap "Agree & Get Started" button to proceed
    final agreeButton = find.text('Agree & Get Started');
    expect(agreeButton, findsOneWidget);
    await tester.tap(agreeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // Verifies transition to main screen
    expect(find.text('MaQui'), findsOneWidget);
  });

  testWidgets('Subsequent app launch skips privacy policy and goes directly to home', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'has_accepted_offline_privacy_policy_v1': true,
    });

    await tester.pumpWidget(const LocalAiQuizApp());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(SplashScreen), findsOneWidget);

    // Complete splash sequence
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump(const Duration(milliseconds: 1200));

    // Privacy policy is NOT shown; main screen with MaQui AppBar is directly visible
    expect(find.text('Welcome & Offline Privacy Promise'), findsNothing);
    expect(find.text('MaQui'), findsOneWidget);
  });
}
