// Tiny hand-rolled formatters so the project doesn't need the `intl`
// package just to print "Mon, 17 Sept" or "9:30 AM". Swap these for
// intl's DateFormat later if you need locale support.

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatWeekdayDate(DateTime date) {
  final weekday = _weekdays[date.weekday - 1];
  final month = _months[date.month - 1];
  return '$weekday, $month ${date.day}';
}

String formatTime(DateTime date) {
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:$minute $period';
}

String formatEstimate(Duration d) {
  if (d.inMinutes < 60) return '~${d.inMinutes} min';
  final hours = d.inMinutes / 60;
  final rounded =
      hours == hours.roundToDouble() ? hours.toInt().toString() : hours.toStringAsFixed(1);
  return '~$rounded ${hours == 1 ? 'hour' : 'hours'}';
}
