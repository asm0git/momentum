import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/widgets/confirmation_dialog_actions.dart';

void main() {
  testWidgets('confirmation actions are full width, stacked, and clickable', (
    tester,
  ) async {
    var cancelled = false;
    var actioned = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: DialogActionButtons(
                cancelLabel: 'Cancel',
                actionLabel: 'Delete',
                onCancel: () => cancelled = true,
                onAction: () => actioned = true,
                actionColor: AppColors.error,
              ),
            ),
          ),
        ),
      ),
    );

    final cancelFinder = find.widgetWithText(FilledButton, 'Cancel');
    final actionFinder = find.widgetWithText(FilledButton, 'Delete');
    final cancelMaterialRect = tester.getRect(
      find.descendant(of: cancelFinder, matching: find.byType(Material)),
    );
    final actionMaterialRect = tester.getRect(
      find.descendant(of: actionFinder, matching: find.byType(Material)),
    );
    expect(cancelMaterialRect.width, 300);
    expect(actionMaterialRect.width, 300);
    expect(cancelMaterialRect.height, 48);
    expect(actionMaterialRect.height, 48);
    expect(actionMaterialRect.top - cancelMaterialRect.bottom, 4);

    final cancelButton = tester.widget<FilledButton>(cancelFinder);
    final actionButton = tester.widget<FilledButton>(actionFinder);
    expect(actionButton.style?.backgroundColor?.resolve({}), AppColors.error);
    await tester.tap(cancelFinder);
    await tester.tap(actionFinder);
    expect(cancelled, isTrue);
    expect(actioned, isTrue);
    expect(cancelButton.onPressed, isNotNull);
  });

  testWidgets('disabled move action uses the disabled color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: DialogActionButtons(
                cancelLabel: 'Cancel',
                actionLabel: 'Move & delete',
                onCancel: () {},
                onAction: null,
                actionColor: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Move & delete'),
    );
    expect(button.onPressed, isNull);
    expect(
      button.style?.backgroundColor?.resolve({WidgetState.disabled}),
      AppColors.disabled,
    );
  });
}
