// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:schedule_planner/main.dart';
import 'package:schedule_planner/schedule/add_schedule_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows login and register options when user is not logged in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyScheduleApp());
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsAtLeastNWidgets(1));
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('shows login page when saved session is stale or incomplete', (
    WidgetTester tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('schedule_planner_logged_in', true);
    await prefs.remove('schedule_planner_current_user');

    await tester.pumpWidget(const MyScheduleApp());
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsAtLeastNWidgets(1));
    expect(find.text('Register'), findsOneWidget);
  });

  testWidgets('shows reminder option in add schedule form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddSchedulePage()));
    await tester.pumpAndSettle();

    expect(find.text('Reminder'), findsOneWidget);
  });

  testWidgets('shows hour-based alarm reminder choices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddSchedulePage()));
    await tester.pumpAndSettle();

    final dropdown = find.byType(DropdownButtonFormField<int>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('1 hour before'), findsAtLeastNWidgets(1));
    expect(find.text('2 hours before'), findsAtLeastNWidgets(1));
    expect(find.text('6 hours before'), findsAtLeastNWidgets(1));
  });
}
