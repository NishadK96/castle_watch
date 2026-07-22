// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:castle_watch/app.dart';
import 'package:castle_watch/presentation/screens/dashboard_screen.dart';
import 'package:castle_watch/presentation/screens/notifications_screen.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets(
    'missing configuration is reported instead of showing demo data',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: CastleWatchApp()));
      await tester.pump();
      expect(find.text('CASTLE WATCH'), findsOneWidget);
      expect(find.textContaining('Supabase is not configured'), findsOneWidget);
      expect(find.text('Iron Citadel'), findsNothing);
    },
  );

  testWidgets('dashboard fits a narrow mobile viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardScreen())),
    );
    await tester.pump();

    expect(find.text('Command center'), findsOneWidget);
    expect(find.text('TOTAL ACCOUNTS'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(320, 568);
    await tester.pump();
    expect(find.text('Command center'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification settings fit a narrow mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: NotificationSettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('PUSH REMINDERS'), findsOneWidget);
    expect(find.text('Push notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
