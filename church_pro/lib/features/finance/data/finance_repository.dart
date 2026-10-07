import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../data/firebase/firebase_helpers.dart';
import '../domain/finance_models.dart';

/// churches/{c}/funds/{id}          name, restricted, balance, active
/// churches/{c}/categories/{id}     name, type
/// churches/{c}/transactions/{id}   the ledger (never deleted, only voided)
///
/// Fund balances and budget-line counters are kept with atomic increments in the
/// same batch as the transaction, so they always agree with the ledger.
class FinanceRepository {
  FinanceRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _church(String c) => _db.collection('churches').doc(c);
  CollectionReference<Map<String, dynamic>> _tx(String c) => _church(c).collection('transactions');
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Fund>> watchFunds(String churchId) => _church(churchId).collection('funds').snapshots().map(
        (s) => s.docs
            .map((d) => Fund(
                  id: d.id,
                  name: stringOf(d.data()['name']),
                  restricted: d.data()['restricted'] == true,
                  balance: (d.data()['balance'] as num?)?.toInt() ?? 0,
                  active: d.data()['active'] != false,
                ))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
      );

  Stream<List<FinanceCategory>> watchCategories(String churchId) =>
      _church(churchId).collection('categories').snapshots().map(
            (s) => s.docs
                .map((d) => FinanceCategory(
                      id: d.id,
                      name: stringOf(d.data()['name']),
                      type: enumByName(TxType.values, d.data()['type'], TxType.expense),
                    ))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
          );

  Stream<List<FinanceTransaction>> watchTransactions(String churchId, {DateTime? since, int? limit}) {
    Query<Map<String, dynamic>> q = _tx(churchId);
    if (since != null) q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    q = q.orderBy('date', descending: true);
    if (limit != null) q = q.limit(limit);
    return q.snapshots().map((s) => s.docs.map(_fromDoc).toList());
  }

  FinanceTransaction _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return FinanceTransaction(
      id: d.id,
      type: enumByName(TxType.values, m['type'], TxType.expense),
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      fundId: stringOf(m['fundId']),
      fundName: stringOf(m['fundName']),
      categoryId: stringOf(m['categoryId']),
      categoryName: stringOf(m['categoryName']),
      method: enumByName(PaymentMethod.values, m['method'], PaymentMethod.cash),
      date: dateFrom(m['date']),
      description: stringOf(m['description']),
      memberId: m['memberId'] as String?,
      memberName: m['memberName'] as String?,
      source: stringOf(m['source']).isEmpty ? 'manual' : stringOf(m['source']),
      requisitionId: m['requisitionId'] as String?,
      budgetId: m['budgetId'] as String?,
      budgetLineId: m['budgetLineId'] as String?,
      voided: m['status'] == 'voided',
    );
  }

  /// Chart of accounts every church starts with. Safe to call repeatedly:
  /// ids are fixed and balances are only ever incremented by 0.
  Future<void> ensureDefaults(String churchId) async {
    final batch = _db.batch();
    const funds = {
      'general': ('General fund', false),
      'building': ('Building fund', true),
      'missions': ('Missions fund', true),
      'welfare': ('Welfare fund', true),
    };
    funds.forEach((id, f) {
      batch.set(
        _church(churchId).collection('funds').doc(id),
        {'name': f.$1, 'restricted': f.$2, 'active': true, 'balance': FieldValue.increment(0)},
        SetOptions(merge: true),
      );
    });
    const categories = {
      'tithe': ('Tithes', TxType.income),
      'offering': ('Offerings', TxType.income),
      'thanksgiving': ('Thanksgiving', TxType.income),
      'donation': ('Donations', TxType.income),
      'pledge': ('Pledge payments', TxType.income),
      'salaries': ('Salaries & allowances', TxType.expense),
      'utilities': ('Utilities', TxType.expense),
      'maintenance': ('Repairs & maintenance', TxType.expense),
      'equipment': ('Equipment & supplies', TxType.expense),
      'outreach': ('Outreach & missions', TxType.expense),
      'welfare': ('Welfare & support', TxType.expense),
      'events': ('Events & programs', TxType.expense),
      'admin': ('Administration', TxType.expense),
    };
    categories.forEach((id, c) {
      batch.set(
        _church(churchId).collection('categories').doc(id),
        {'name': c.$1, 'type': c.$2.name},
        SetOptions(merge: true),
      );
    });
    await queued(batch.commit());
  }

  /// Adds a ledger entry to [batch]: the transaction, the fund balance, and the
  /// budget line. [releaseCommitted] frees money reserved by an approved purchase.
  DocumentReference<Map<String, dynamic>> stageTransaction(
    WriteBatch batch,
    String churchId,
    FinanceTransaction t, {
    int releaseCommitted = 0,
  }) {
    final ref = _tx(churchId).doc();
    batch.set(ref, {
      'type': t.type.name,
      'amount': t.amount,
      'fundId': t.fundId,
      'fundName': t.fundName,
      'categoryId': t.categoryId,
      'categoryName': t.categoryName,
      'method': t.method.name,
      'date': Timestamp.fromDate(t.date),
      'description': t.description,
      'memberId': t.memberId,
      'memberName': t.memberName,
      'source': t.source,
      'requisitionId': t.requisitionId,
      'budgetId': t.budgetId,
      'budgetLineId': t.budgetLineId,
      'status': 'confirmed',
      'recordedBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_church(churchId).collection('funds').doc(t.fundId), {
      'balance': FieldValue.increment(t.signedAmount),
    });
    if (t.budgetId != null && t.budgetLineId != null) {
      batch.update(
        _church(churchId).collection('budgets').doc(t.budgetId).collection('lines').doc(t.budgetLineId),
        {
          'actual': FieldValue.increment(t.amount),
          if (releaseCommitted > 0) 'committed': FieldValue.increment(-releaseCommitted),
        },
      );
    }
    return ref;
  }

  Future<void> record(String churchId, FinanceTransaction t) {
    final batch = _db.batch();
    stageTransaction(batch, churchId, t);
    return queued(batch.commit());
  }

  Future<void> voidTransaction(String churchId, FinanceTransaction t) {
    final batch = _db.batch();
    batch.update(_tx(churchId).doc(t.id), {
      'status': 'voided',
      'voidedAt': FieldValue.serverTimestamp(),
      'voidedBy': _uid,
    });
    batch.update(_church(churchId).collection('funds').doc(t.fundId), {
      'balance': FieldValue.increment(-t.signedAmount),
    });
    if (t.budgetId != null && t.budgetLineId != null) {
      batch.update(
        _church(churchId).collection('budgets').doc(t.budgetId).collection('lines').doc(t.budgetLineId),
        {'actual': FieldValue.increment(-t.amount)},
      );
    }
    return queued(batch.commit());
  }
}
