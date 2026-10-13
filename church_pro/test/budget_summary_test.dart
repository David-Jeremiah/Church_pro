import 'package:church_pro/features/budget/domain/budget_models.dart';
import 'package:church_pro/features/budget/domain/budget_summary.dart';
import 'package:church_pro/features/finance/domain/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 12);

  Budget budget(String status, {DateTime? submittedAt}) => Budget(
        id: 'b1',
        name: 'Budget 2026',
        year: 2026,
        status: status,
        submittedByName: 'Grace',
        submittedAt: submittedAt,
      );

  BudgetLine line(String name, int planned, {int actual = 0, int committed = 0, TxType type = TxType.expense}) =>
      BudgetLine(id: name, budgetId: 'b1', name: name, type: type, planned: planned, actual: actual, committed: committed);

  test('a budget with no lines asks for lines', () {
    final s = buildBudgetSummary(budget: budget('draft'), lines: const [], comments: const [], currency: 'UGX', now: today);
    expect(s.standing.join(' '), contains('no lines yet'));
    expect(s.next.first, 'Add the budget lines.');
  });

  test('a line over its plan is flagged', () {
    final s = buildBudgetSummary(
      budget: budget('active'),
      lines: [line('Electricity', 1000000, actual: 1200000), line('Offerings', 5000000, type: TxType.income)],
      comments: const [],
      currency: 'UGX',
      now: today,
    );
    expect(s.watch.any((w) => w.contains('"Electricity" is over its plan by UGX 200,000')), isTrue);
  });

  test('a plan with more expenses than income is short', () {
    final s = buildBudgetSummary(
      budget: budget('draft'),
      lines: [line('Salaries', 9000000), line('Tithes', 6000000, type: TxType.income)],
      comments: const [],
      currency: 'UGX',
      now: today,
    );
    expect(s.standing.join(' '), contains('short by UGX 3,000,000'));
  });

  test('a budget waiting a long time for approval is flagged', () {
    final s = buildBudgetSummary(
      budget: budget('pending_approval', submittedAt: today.subtract(const Duration(days: 9))),
      lines: [line('Repairs', 500000)],
      comments: const [],
      currency: 'UGX',
      now: today,
    );
    expect(s.watch.any((w) => w.contains('9 days')), isTrue);
    expect(s.standing.first, contains('waiting for the lead pastor'));
  });
}
