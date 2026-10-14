import '../../data/recurrence.dart';

DateTime mondayOf(DateTime date) {
  final day = dateOnly(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

String formatFocusDuration(int seconds) {
  if (seconds <= 0) return '0 mins';
  if (seconds < 60) return '${seconds}s';

  final totalMinutes = seconds ~/ 60;
  final hours = totalMinutes ~/ 60;
  final remainingMinutes = totalMinutes % 60;
  if (hours == 0) {
    return '$totalMinutes ${totalMinutes == 1 ? 'min' : 'mins'}';
  }
  final hourLabel = '$hours ${hours == 1 ? 'hr' : 'hrs'}';
  if (remainingMinutes == 0) return hourLabel;
  final minuteLabel =
      '$remainingMinutes ${remainingMinutes == 1 ? 'min' : 'mins'}';
  return '$hourLabel $minuteLabel';
}

String weekdayShortLabel(int weekday) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

String weekdayNameLabel(int weekday) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][weekday - 1];

String monthNameLabel(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

String monthShortLabel(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];
