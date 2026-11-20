import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/lessons/horizontal_reading_view.dart';

void main() {
  testWidgets(
    'wide content exposes its scrollbar, hint and working horizontal movement',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: HorizontalReadingView(
                  hint: 'আরও দেখতে ডানে-বাঁয়ে সরান।',
                  child: SizedBox(width: 1000, height: 80),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('আরও দেখতে ডানে-বাঁয়ে সরান।'), findsOneWidget);
      expect(
        tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility,
        isTrue,
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-180, 0),
      );
      await tester.pumpAndSettle();
      final view = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(view.controller!.offset, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hint disappears when the same block becomes short enough', (
    tester,
  ) async {
    const key = ValueKey('same-reading-block');
    Widget page(double width) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 240,
            child: HorizontalReadingView(
              key: key,
              hint: 'আরও দেখতে ডানে-বাঁয়ে সরান।',
              child: SizedBox(width: width, height: 80),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(page(1000));
    await tester.pumpAndSettle();
    expect(find.text('আরও দেখতে ডানে-বাঁয়ে সরান।'), findsOneWidget);
    await tester.pumpWidget(page(40));
    await tester.pumpAndSettle();
    expect(find.text('আরও দেখতে ডানে-বাঁয়ে সরান।'), findsNothing);
    expect(
      tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
