import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/widgets/item_editor/estimated_duration_picker.dart';

void main() {
  testWidgets('duration picker keeps its default label and picker behavior', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: EstimatedDurationPicker(
            value: const Duration(minutes: 30),
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Estimated duration'), findsOneWidget);
    await tester.tap(find.text('Estimated duration'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Estimated duration'),
      ),
      findsOneWidget,
    );
    expect(find.text('Estimated duration'), findsNWidgets(2));
    expect(find.byType(CupertinoPicker), findsNWidgets(2));
    expect(find.text('hours'), findsOneWidget);
    expect(find.text('mins'), findsOneWidget);
  });
}
