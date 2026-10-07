import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/firebase/firebase_helpers.dart';
import '../../finance/domain/finance_models.dart';
import '../domain/budget_models.dart';

/// churches/{c}/budgets/{id}              name, year, status
/// churches/{c}/budgets/{id}/lines/{id}   name, type, planned, committed, actual
class BudgetRepository {
  BudgetRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _budgets(String c) =>
      _db.collection('churches').doc(c).collection('budgets');

  Stream<List<Budget>> watchBudgets(String churchId) => _budgets(churchId).snapshots().map(
        (s) => s.docs
            .map((d) => Budget(
                  id: d.id,
                  name: stringOf(d.data()['name']),
                  year: (d.data()['year'] as num?)?.toInt() ?? 0,
                  status: stringOf(d.data()['status']).isEmpty ? 'draft' : stringOf(d.data()['status']),
                ))
            .toList()
          ..sort((a, b) => b.year.compareTo(a.year)),
      );

  Stream<List<BudgetLine>> watchLines(String churchId, String budgetId) =>
      _budgets(churchId).doc(budgetId).collection('lines').snapshots().map(
            (s) => s.docs
                .map((d) => BudgetLine(
                      id: d.id,
                      budgetId: budgetId,
                      name: stringOf(d.data()['name']),
                      type: enumByName(TxType.values, d.data()['type'], TxType.expense),
                      planned: (d.data()['planned'] as num?)?.toInt() ?? 0,
                      committed: (d.data()['committed'] as num?)?.toInt() ?? 0,
                      actual: (d.data()['actual'] as num?)?.toInt() ?? 0,
                    ))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
          );

  Future<void> createBudget(String churchId, {required String name, required int year}) =>
      queued(_budgets(churchId).doc().set({
        'name': name,
        'year': year,
        'status': 'draft',
        'createdAt': FieldValue.serverTimestamp(),
      }));

  /// Makes [budgetId] the only active budget (the previous one is closed).
  Future<void> activate(String churchId, String budgetId, {String? previousActiveId}) {
    final batch = _db.batch();
    if (previousActiveId != null && previousActiveId != budgetId) {
      batch.update(_budgets(churchId).doc(previousActiveId), {'status': 'closed'});
    }
    batch.update(_budgets(churchId).doc(budgetId), {'status': 'active'});
    return queued(batch.commit());
  }

  Future<void> addLine(
    String churchId,
    String budgetId, {
    required String name,
    required TxType type,
    required int planned,
  }) =>
      queued(_budgets(churchId).doc(budgetId).collection('lines').doc().set({
        'name': name,
        'type': type.name,
        'planned': planned,
        'committed': 0,
        'actual': 0,
      }));

  Future<void> updatePlanned(String churchId, String budgetId, String lineId, int planned) =>
      queued(_budgets(churchId).doc(budgetId).collection('lines').doc(lineId).update({'planned': planned}));
}
