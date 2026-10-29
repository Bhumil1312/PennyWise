import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywise_mobile/main.dart';

void main() {
  testWidgets(
    'mobile demo shows dashboard, people, investments and settings without layout errors',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const PennyWiseApp());
      await tester.ensureVisible(find.text('Explore the demo'));
      await tester.tap(find.text('Explore the demo'));
      await tester.pumpAndSettle();
      expect(find.text('Your money, in focus.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('People'));
      await tester.pumpAndSettle();
      expect(find.text('Aarav'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Investments'));
      await tester.pumpAndSettle();
      expect(find.text('Nifty 50 index fund'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy & storage'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('desktop can review and save a described transaction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const PennyWiseApp());
    await tester.ensureVisible(find.text('Explore the demo'));
    await tester.tap(find.text('Explore the demo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Paid ₹450 for coffee today',
    );
    await tester.tap(find.byTooltip('Review description'));
    await tester.pumpAndSettle();
    expect(find.text('Review transaction'), findsOneWidget);
    await tester.tap(find.text('Confirm & save transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Review transaction'), findsNothing);
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Paid ₹450 for coffee today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
