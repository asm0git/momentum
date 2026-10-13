import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/data/debug_demo_data.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/screens/insights_screen.dart';

void main() {
  test('demo calendar category creates a future read-only event', () {
    final category = DebugDemoData.googleCalendarCategory(
      now: DateTime(2026, 10, 14, 10, 30),
    );
    final event = category.items.single as Event;

    expect(category.id, DebugDemoData.googleCategoryId);
    expect(category.title, 'Google Calendar');
    expect(category.iconName, 'provider_google');
    expect(event.id, DebugDemoData.googleEventId);
    expect(event.categoryId, category.id);
    expect(event.title, 'Project planning');
    expect(event.date, DateTime(2026, 10, 14));
    expect(event.start.hour, 12);
    expect(event.start.minute, 30);
    expect(event.end.hour, 13);
    expect(event.end.minute, 30);
    expect(event.allDay, isFalse);
    expect(event.sourcePlatform, 'google');
    expect(event.externalId, 'momentum-debug-google-event');
  });

  test('demo focus data varies across days and all heatmap shades', () {
    final today = DateTime(2026, 10, 12);
    final firstDay = today.subtract(const Duration(days: 363));
    final sample = DebugDemoData.focusByDay(
      firstDay: firstDay,
      lastDay: today,
      now: today,
    );
    final totalsByDay = {
      for (final entry in sample.entries)
        entry.key: entry.value.fold<int>(
          0,
          (total, category) => total + category.totalSeconds,
        ),
    };
    final shadeCounts = List<int>.filled(5, 0);
    final activeDaysByWeekday = List<int>.filled(7, 0);

    for (var offset = 0; offset < 364; offset++) {
      final date = today.subtract(Duration(days: offset));
      final seconds = totalsByDay[date] ?? 0;
      shadeCounts[focusHeatmapLevelForSeconds(seconds)]++;
      if (seconds > 0) activeDaysByWeekday[date.weekday - 1]++;
    }

    expect(shadeCounts[0], greaterThan(40));
    for (final count in shadeCounts.skip(1)) {
      expect(count, greaterThan(20));
    }
    for (final count in activeDaysByWeekday) {
      expect(count, greaterThan(20));
    }
  });

  test('heatmap shade thresholds match the legend order', () {
    expect(focusHeatmapLevelForSeconds(0), 0);
    expect(focusHeatmapLevelForSeconds(1), 1);
    expect(focusHeatmapLevelForSeconds(30 * 60 - 1), 1);
    expect(focusHeatmapLevelForSeconds(30 * 60), 2);
    expect(focusHeatmapLevelForSeconds(60 * 60 - 1), 2);
    expect(focusHeatmapLevelForSeconds(60 * 60), 3);
    expect(focusHeatmapLevelForSeconds(2 * 60 * 60), 3);
    expect(focusHeatmapLevelForSeconds(2 * 60 * 60 + 1), 4);
  });
}
