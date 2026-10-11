enum CalendarViewMode {
  oneWeekWithoutIndicators(1, 'Compact one week'),
  oneWeek(1, 'One week'),
  twoWeeks(2, 'Two weeks'),
  fourWeeksWithoutIndicators(4, 'Four weeks without task indicators'),
  fullMonth(null, 'Full month');

  const CalendarViewMode(this.visibleWeekCount, this.label);

  final int? visibleWeekCount;
  final String label;

  bool get showTaskIndicators =>
      this != CalendarViewMode.oneWeekWithoutIndicators &&
      this != CalendarViewMode.fourWeeksWithoutIndicators;

  bool get usesDateOnlyWeekHeight =>
      this == CalendarViewMode.oneWeekWithoutIndicators;

  CalendarViewMode? get smallerMode =>
      index == 0 ? null : CalendarViewMode.values[index - 1];

  CalendarViewMode? get largerMode =>
      index == CalendarViewMode.values.length - 1
      ? null
      : CalendarViewMode.values[index + 1];

  static CalendarViewMode fromPreferenceValue(String? value) =>
      CalendarViewMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => CalendarViewMode.fullMonth,
      );
}
