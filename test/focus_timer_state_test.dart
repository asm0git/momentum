import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/planner_repository.dart';
import 'package:momentum/state/focus_timer_state.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late DatabaseHelper databaseHelper;
  late PlannerState planner;
  late DateTime now;
  late FocusTimerState timer;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('momentum_focus_');
    databaseHelper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: p.join(tempDirectory.path, 'focus.db'),
      seedOnCreate: false,
    );
    planner = PlannerState(
      repository: PlannerRepository(databaseHelper: databaseHelper),
    );
    await planner.initialize();
    now = DateTime(2026, 10, 9, 10);
    timer = FocusTimerState(
      workMinutes: 1,
      breakMinutes: 1,
      clock: () => now,
      startTicker: false,
    )..attachPlannerState(planner);
    await planner.getFocusSecondsForDate(now);
  });

  tearDown(() async {
    if (timer.isRunning) timer.toggleRunning();
    await timer.flushPendingForTesting();
    timer.dispose();
    planner.dispose();
    await databaseHelper.close();
    await tempDirectory.delete(recursive: true);
  });

  test('work phases cycle continuously into rest and back to work', () async {
    timer.toggleRunning();
    now = now.add(const Duration(seconds: 65));
    await timer.tickForTesting();

    expect(timer.isRunning, isTrue);
    expect(timer.phase, FocusPhase.rest);
    expect(timer.remainingSeconds, 55);
    expect(timer.totalFocusSecondsToday, 60);

    now = now.add(const Duration(seconds: 55));
    await timer.tickForTesting();
    expect(timer.phase, FocusPhase.work);
    expect(timer.remainingSeconds, 60);
    expect(timer.totalFocusSecondsToday, 60);
  });

  test('pause and resume accumulates only work seconds', () async {
    timer.toggleRunning();
    now = now.add(const Duration(seconds: 10));
    await timer.tickForTesting();
    timer.toggleRunning();
    await timer.flushPendingForTesting();
    expect(await planner.getFocusSecondsForDate(now), 10);

    timer.toggleRunning();
    now = now.add(const Duration(seconds: 5));
    await timer.tickForTesting();
    timer.toggleRunning();
    await timer.flushPendingForTesting();

    expect(timer.totalFocusSecondsToday, 15);
    expect(await planner.getFocusSecondsForDate(now), 15);
  });

  test(
    'preset selection applies immediately and resets the current phase',
    () async {
      timer.toggleRunning();
      now = now.add(const Duration(seconds: 12));
      await timer.tickForTesting();
      timer.selectPreset(workMinutes: 45, breakMinutes: 10);

      expect(timer.isRunning, isTrue);
      expect(timer.phase, FocusPhase.work);
      expect(timer.workMinutes, 45);
      expect(timer.breakMinutes, 10);
      expect(timer.remainingSeconds, 45 * 60);
      expect(timer.totalFocusSecondsToday, 12);
      timer.toggleRunning();
      await timer.flushPendingForTesting();
    },
  );

  test(
    'focus totals split at local midnight and persist by calendar date',
    () async {
      timer.dispose();
      now = DateTime(2026, 10, 9, 23, 59, 58);
      timer = FocusTimerState(
        workMinutes: 1,
        breakMinutes: 1,
        clock: () => now,
        startTicker: false,
      )..attachPlannerState(planner);
      await planner.getFocusSecondsForDate(now);

      timer.toggleRunning();
      now = now.add(const Duration(seconds: 5));
      await timer.tickForTesting();
      await timer.flushPendingForTesting();

      expect(await planner.getFocusSecondsForDate(DateTime(2026, 10, 9)), 2);
      expect(await planner.getFocusSecondsForDate(DateTime(2026, 10, 10)), 3);
      expect(timer.totalFocusSecondsToday, 3);
    },
  );
}
