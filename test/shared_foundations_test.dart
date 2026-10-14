import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/data/sample_data.dart';
import 'package:momentum/navigation_destinations.dart';
import 'package:momentum/widgets/blurred_dialog.dart';
import 'package:momentum/widgets/circular_icon_button.dart';
import 'package:momentum/widgets/selector.dart';

void main() {
  test('new planner samples have stable empty starter categories', () {
    final categories = createSampleCategories();

    expect(categories.map((category) => (category.title, category.iconName)), [
      ('School', 'school'),
      ('Personal', 'personal'),
      ('Work', 'work'),
      ('Gym', 'gym'),
    ]);
    expect(categories.every((category) => category.items.isEmpty), isTrue);
    expect(createSampleCategories(), isNot(same(categories)));
  });

  test('main destinations keep unique routes and stable labels', () {
    expect(
      AppDestination.values
          .map((destination) => destination.route)
          .toSet()
          .length,
      AppDestination.values.length,
    );
    expect(AppDestination.values.map((destination) => destination.title), [
      'Dashboard',
      'Calendar',
      'Timer',
      'Insights',
      'To-Do',
    ]);
    expect(AppDestination.values.map((destination) => destination.route), [
      '/dashboard',
      '/calendar',
      '/timer',
      '/insights',
      '/todo',
    ]);
  });

  testWidgets('circular icon button exposes its tooltip and action', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CircularIconButton(
            backgroundColor: Colors.purple,
            icon: Icons.add,
            tooltip: 'Add item',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Add item'));

    expect(pressed, isTrue);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('selector reports the selected option', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Selector<String>(
              options: const [
                SelectorOption(value: 'school', label: 'School'),
                SelectorOption(value: 'work', label: 'Work'),
              ],
              selectedValue: 'school',
              placeholder: 'Choose a category',
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('School'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').last);

    expect(selected, 'work');
  });

  testWidgets('blurred dialog shows its barrier and closes from its action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBlurredDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  content: const Text('Dialog content'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Dialog content'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Dialog content'), findsNothing);
  });
}
