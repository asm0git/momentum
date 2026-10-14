import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/widgets/planner/dashboard_category_card.dart';

void main() {
  testWidgets('category card shows the next task and supplied pending count', (
    tester,
  ) async {
    final nextTask = Task(
      title: 'Read chapter',
      date: DateTime(2026, 10, 12),
      isChecked: false,
      time: const TimeOfDay(hour: 15, minute: 5),
      estimatedDuration: Duration.zero,
    );
    final category = TaskCategory(
      title: 'School',
      iconName: '',
      items: const [],
    );
    var tapCount = 0;

    await tester.pumpWidget(
      _app(
        DashboardCategoryCard(
          category: category,
          nextItem: nextTask,
          onTap: () => tapCount++,
          pendingCount: 3,
        ),
      ),
    );

    expect(find.text('School'), findsOneWidget);
    expect(find.text('3 pending'), findsOneWidget);
    expect(find.text('Read chapter'), findsOneWidget);
    expect(find.text('Monday, 3:05 PM'), findsOneWidget);
    await tester.tap(find.text('School'));
    expect(tapCount, 1);
  });

  testWidgets(
    'category card hides pending count and formats all-day previews',
    (tester) async {
      final allDayEvent = Event(
        title: 'Exam day',
        date: DateTime(2026, 10, 12),
        start: const TimeOfDay(hour: 0, minute: 0),
        end: const TimeOfDay(hour: 0, minute: 0),
        isCurrent: false,
        allDay: true,
      );
      final category = TaskCategory(
        title: 'School',
        iconName: '',
        items: const [],
      );

      await tester.pumpWidget(
        _app(
          DashboardCategoryCard(
            category: category,
            nextItem: allDayEvent,
            onTap: () {},
            showPendingCount: false,
          ),
        ),
      );

      expect(find.text('pending'), findsNothing);
      expect(find.text('Exam day'), findsOneWidget);
      expect(find.text('Monday'), findsOneWidget);

      await tester.pumpWidget(
        _app(
          DashboardCategoryCard(
            category: category,
            nextItem: null,
            onTap: () {},
            showPendingCount: false,
          ),
        ),
      );
      expect(find.text('No upcoming items'), findsOneWidget);
    },
  );
}

Widget _app(Widget card) => MaterialApp(
  theme: appTheme,
  home: Scaffold(body: Center(child: card)),
);
