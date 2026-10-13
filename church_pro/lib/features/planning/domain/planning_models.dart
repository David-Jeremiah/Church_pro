import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

/// One slot in the church's usual Sunday pattern, e.g. "1st service" at 7:00 AM.
class ServiceSlot {
  const ServiceSlot({required this.name, required this.time});

  final String name;
  final String time;

  static const defaults = <ServiceSlot>[
    ServiceSlot(name: '1st service', time: '7:00 AM'),
    ServiceSlot(name: '2nd service', time: '9:30 AM'),
    ServiceSlot(name: '3rd service', time: '12:00 PM'),
  ];

  Map<String, dynamic> toMap() => {'name': name, 'time': time};

  factory ServiceSlot.fromMap(Map<String, dynamic> m) =>
      ServiceSlot(name: (m['name'] ?? '') as String, time: (m['time'] ?? '') as String);
}

/// A service on a particular Sunday, with who preaches and who leads.
class PlannedService {
  const PlannedService({
    this.id = '',
    required this.date,
    required this.name,
    this.time = '',
    this.preacher = '',
    this.leader = '',
    this.isJoint = false,
    this.order = 0,
  });

  final String id;
  final DateTime date;
  final String name;
  final String time;
  final String preacher;
  final String leader;
  final bool isJoint;
  final int order;

  bool get hasPreacher => preacher.trim().isNotEmpty;
  bool get hasLeader => leader.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    'date': Timestamp.fromDate(_midnight(date)),
    'name': name,
    'time': time,
    'preacher': preacher,
    'leader': leader,
    'isJoint': isJoint,
    'order': order,
  };

  factory PlannedService.fromMap(String id, Map<String, dynamic> m) => PlannedService(
    id: id,
    date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    name: (m['name'] ?? '') as String,
    time: (m['time'] ?? '') as String,
    preacher: (m['preacher'] ?? '') as String,
    leader: (m['leader'] ?? '') as String,
    isJoint: (m['isJoint'] ?? false) as bool,
    order: (m['order'] as num?)?.toInt() ?? 0,
  );
}

enum CalendarKind {
  event('Event', Icons.event),
  meeting('Meeting', Icons.groups_outlined),
  holiday('Holiday', Icons.celebration_outlined),
  other('Other', Icons.push_pin_outlined);

  const CalendarKind(this.label, this.icon);
  final String label;
  final IconData icon;

  static CalendarKind parse(String? v) =>
      CalendarKind.values.firstWhere((k) => k.name == v, orElse: () => CalendarKind.other);
}

/// A date worth remembering: a meeting, an event, a holiday.
class CalendarItem {
  const CalendarItem({
    this.id = '',
    required this.title,
    required this.date,
    this.time = '',
    this.kind = CalendarKind.event,
    this.notes = '',
  });

  final String id;
  final String title;
  final DateTime date;
  final String time;
  final CalendarKind kind;
  final String notes;

  Map<String, dynamic> toMap() => {
    'title': title,
    'date': Timestamp.fromDate(_midnight(date)),
    'time': time,
    'kind': kind.name,
    'notes': notes,
  };

  factory CalendarItem.fromMap(String id, Map<String, dynamic> m) => CalendarItem(
    id: id,
    title: (m['title'] ?? '') as String,
    date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    time: (m['time'] ?? '') as String,
    kind: CalendarKind.parse(m['kind'] as String?),
    notes: (m['notes'] ?? '') as String,
  );
}