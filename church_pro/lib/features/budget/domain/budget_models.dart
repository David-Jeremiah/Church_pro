import 'package:flutter/material.dart';

import '../../finance/domain/finance_models.dart';

class Budget {
  const Budget({
    required this.id,
    required this.name,
    required this.year,
    required this.status,
    this.sharedWith = const [],
    this.submittedByName,
    this.submittedAt,
    this.decidedByName,
    this.decidedAt,
    this.decisionNote = '',
    this.aiSummary = '',
    this.aiSummaryAt,
  });

  final String id;
  final String name;
  final int year;

  /// draft, pending_approval, changes_requested, approved, active or closed.
  final String status;

  /// Logins (besides admin, accountant and lead pastor) who can see it while it is prepared.
  final List<String> sharedWith;
  final String? submittedByName;
  final DateTime? submittedAt;
  final String? decidedByName;
  final DateTime? decidedAt;
  final String decisionNote;
  final String aiSummary;
  final DateTime? aiSummaryAt;

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending_approval';
  bool get isApproved => status == 'approved';
  bool get needsChanges => status == 'changes_requested';
  bool get isDraft => status == 'draft';
  bool get isClosed => status == 'closed';

  String get statusLabel => switch (status) {
    'draft' => 'Draft',
    'pending_approval' => 'Waiting for approval',
    'changes_requested' => 'Changes requested',
    'approved' => 'Approved',
    'active' => 'Active',
    'closed' => 'Closed',
    _ => status,
  };

  Color get statusColor => switch (status) {
    'active' => const Color(0xFF2F8F5B),
    'approved' => const Color(0xFF1E6FD9),
    'pending_approval' => const Color(0xFFC77700),
    'changes_requested' => const Color(0xFFB3261E),
    _ => const Color(0xFF6B7A74),
  };

  /// Step in the journey: 0 draft, 1 sent for approval, 2 approved, 3 active.
  int get step => switch (status) {
    'pending_approval' => 1,
    'approved' => 2,
    'active' || 'closed' => 3,
    _ => 0,
  };
}

class BudgetLine {
  const BudgetLine({
    required this.id,
    required this.budgetId,
    required this.name,
    required this.type,
    required this.planned,
    this.committed = 0,
    this.actual = 0,
  });

  final String id;
  final String budgetId;
  final String name;
  final TxType type;
  final int planned;

  /// Reserved by approved purchase requests that are not yet paid.
  final int committed;

  /// Income received / money spent so far.
  final int actual;

  int get remaining => planned - committed - actual;
  double get usedFraction => planned <= 0 ? 0 : ((committed + actual) / planned).clamp(0, 1).toDouble();
}

/// A comment, or an automatic note about a step (sent, approved, made active).
class BudgetComment {
  const BudgetComment({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.authorRole,
    required this.text,
    required this.isEvent,
    required this.createdAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String authorRole;
  final String text;
  final bool isEvent;
  final DateTime createdAt;
}