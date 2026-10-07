class ChurchEvent {
  const ChurchEvent({
    required this.id,
    required this.title,
    required this.start,
    this.location = '',
  });

  final String id;
  final String title;
  final DateTime start;
  final String location;
}
