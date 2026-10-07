import '../../finance/domain/finance_models.dart';

class Budget {
  const Budget({required this.id, required this.name, required this.year, required this.status});

  final String id;
  final String name;
  final int year;

  /// 'draft', 'active' or 'closed'. Only one budget is active at a time.
  final String status;

  bool get isActive => status == 'active';
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
