import 'package:flutter/material.dart';

enum RequisitionStatus {
  submitted('Awaiting approval', Colors.orange),
  approved('Approved', Colors.blue),
  rejected('Rejected', Colors.red),
  ordered('Ordered', Colors.indigo),
  received('Received', Colors.teal),
  paid('Paid', Colors.green),
  cancelled('Cancelled', Colors.grey);

  const RequisitionStatus(this.label, this.color);
  final String label;
  final Color color;
}

class Requisition {
  const Requisition({
    required this.id,
    required this.title,
    required this.amount,
    required this.budgetId,
    required this.budgetLineId,
    required this.budgetLineName,
    required this.status,
    required this.requestedBy,
    required this.requestedByName,
    required this.createdAt,
    this.description = '',
    this.vendor = '',
    this.rejectionReason,
    this.transactionId,
  });

  final String id;
  final String title;
  final String description;
  final String vendor;
  final int amount;
  final String budgetId;
  final String budgetLineId;
  final String budgetLineName;
  final RequisitionStatus status;
  final String requestedBy;
  final String requestedByName;
  final DateTime createdAt;
  final String? rejectionReason;
  final String? transactionId;
}
