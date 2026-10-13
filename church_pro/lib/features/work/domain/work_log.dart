import 'package:flutter/material.dart';

enum WorkMode {
  office('Office', Icons.business),
  home('Home', Icons.home_work_outlined);

  const WorkMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

class WorkLog {
  const WorkLog({
    required this.id,
    required this.uid,
    required this.userName,
    required this.date,
    required this.mode,
    required this.clockIn,
    this.clockOut,
    this.notes = '',
  });

  final String id;
  final String uid;
  final String userName;

  /// yyyy-MM-dd
  final String date;
  final WorkMode mode;
  final DateTime clockIn;
  final DateTime? clockOut;
  final String notes;

  bool get isOpen => clockOut == null;
  Duration? get worked => clockOut?.difference(clockIn);
}