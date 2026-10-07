import 'package:intl/intl.dart';

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

/// Amounts are integers in the currency's smallest unit (UGX has no decimals).
String formatMoney(int amount, {String currency = 'UGX'}) =>
    '$currency ${NumberFormat.decimalPattern().format(amount)}';

String formatDate(DateTime date) => DateFormat.yMMMd().format(date);

String formatTime(DateTime date) => DateFormat.jm().format(date);

/// Stable day key used for work logs, e.g. 2026-10-07.
String dayKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month);

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return h == 0 ? '${m}m' : '${h}h ${m}m';
}
