import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mediconnect/main.dart';
import 'package:mediconnect/screens/home_screen.dart';

void main() {
  setUp(() {
    // Provide a clean/empty SharedPreferences for every test
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Theme toggle test and basic elements render', (WidgetTester tester) async {
    // Enable test mode to disable infinite repeating animation loops
    MediConnectApp.isTestMode = true;

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MediConnectApp());

    // StartupScreen redirects to HomeScreen when no session is saved
    await tester.pumpAndSettle();

    // Verify that our home screen elements exist.
    expect(find.text('MediConnect'), findsOneWidget);
    expect(find.text('I am a Patient'), findsOneWidget);
    expect(find.text('I am a Doctor'), findsOneWidget);

    // Tap the theme toggle icon button
    await tester.tap(find.byIcon(Icons.dark_mode_rounded));
    await tester.pumpAndSettle();

    // Verify that the theme changed to Dark Mode
    final BuildContext darkContext = tester.element(find.byType(HomeScreen));
    expect(Theme.of(darkContext).brightness, Brightness.dark);

    // Tap the theme toggle icon button again to revert
    await tester.tap(find.byIcon(Icons.light_mode_rounded));
    await tester.pumpAndSettle();

    // Verify it is Light Mode again
    final BuildContext lightContext = tester.element(find.byType(HomeScreen));
    expect(Theme.of(lightContext).brightness, Brightness.light);

    // Clean up the widget tree
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Home screen shows no patient portal card when no patients registered', (WidgetTester tester) async {
    MediConnectApp.isTestMode = true;
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MediConnectApp());
    await tester.pumpAndSettle();

    // The "Continue as" quick-access card should NOT be visible when no patients exist
    expect(find.text('Continue as'), findsNothing);
    expect(find.text('SELECT PORTAL'), findsOneWidget);
  });
}
