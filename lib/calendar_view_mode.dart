enum CalendarViewMode {
  oneWeekWithoutIndicators(1, 'Current week without event bars'),
  oneWeek(1, 'Current week with event bars'),
  twoWeeksWithoutIndicators(2, 'Two weeks without event bars'),
  twoWeeks(2, 'Two weeks with event bars'),
  fullMonthWithoutIndicators(null, 'Full month without event bars'),
  fullMonth(null, 'Full month with event bars');

  const CalendarViewMode(this.visibleWeekCount, this.label);

  final int? visibleWeekCount;
  final String label;

  bool get showTaskIndicators =>
      this != CalendarViewMode.oneWeekWithoutIndicators &&
      this != CalendarViewMode.twoWeeksWithoutIndicators &&
      this != CalendarViewMode.fullMonthWithoutIndicators;

  bool get usesDateOnlyWeekHeight => !showTaskIndicators;

  bool get showsWholeMonth => visibleWeekCount == null;

  CalendarViewMode? get smallerMode =>
      index == 0 ? null : CalendarViewMode.values[index - 1];

  CalendarViewMode? get largerMode =>
      index == CalendarViewMode.values.length - 1
      ? null
      : CalendarViewMode.values[index + 1];

  static CalendarViewMode fromPreferenceValue(String? value) {
    if (value == 'fourWeeksWithoutIndicators') {
      return CalendarViewMode.fullMonthWithoutIndicators;
    }
    return CalendarViewMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => CalendarViewMode.fullMonth,
    );
  }
}
