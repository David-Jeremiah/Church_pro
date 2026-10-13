/// True when [a] and [b] fall on the same calendar day.
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Today if it is a Sunday, otherwise the coming Sunday (time stripped).
DateTime sundayOnOrAfter(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.add(Duration(days: (7 - day.weekday % 7) % 7));
}