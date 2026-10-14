import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/widgets/item_editor/add_item_popup.dart';

void main() {
  testWidgets('new category actions use the shared popup button typography', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showNewCategoryDialog(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final expectedStyle = appTheme.textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.normal,
    );
    final cancel = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Cancel'),
    );
    final create = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create'),
    );

    _expectTypography(cancel.style?.textStyle?.resolve({}), expectedStyle);
    _expectTypography(create.style?.textStyle?.resolve({}), expectedStyle);
    expect(cancel.style?.foregroundColor, isNull);
    expect(create.style?.backgroundColor, isNull);
    expect(create.style?.foregroundColor, isNull);
  });
}

void _expectTypography(TextStyle? actual, TextStyle expected) {
  expect(actual?.fontFamily, expected.fontFamily);
  expect(actual?.fontSize, expected.fontSize);
  expect(actual?.fontWeight, expected.fontWeight);
  expect(actual?.letterSpacing, expected.letterSpacing);
  expect(actual?.height, expected.height);
}
