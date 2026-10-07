import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../data/firebase/firebase_helpers.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/domain/finance_models.dart';
import '../domain/requisition.dart';

/// churches/{c}/requisitions/{id}
///
/// Flow: submitted -> approved (budget committed) -> ordered -> received -> paid
/// (expense posted to the ledger and the commitment released). A request can be
/// rejected while submitted, or cancelled before it is ordered.
class ProcurementRepository {
  ProcurementRepository(this._finance, [FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FinanceRepository _finance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String c) =>
      _db.collection('churches').doc(c).collection('requisitions');
  DocumentReference<Map<String, dynamic>> _line(String c, Requisition r) =>
      _db.collection('churches').doc(c).collection('budgets').doc(r.budgetId).collection('lines').doc(r.budgetLineId);
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Finance roles see every request; other staff see only their own.
  Stream<List<Requisition>> watchRequisitions(String churchId, {String? requesterUid}) {
    Query<Map<String, dynamic>> q = _col(churchId);
    if (requesterUid != null) q = q.where('requestedBy', isEqualTo: requesterUid);
    return q.snapshots().map((s) => s.docs.map(_fromDoc).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Requisition _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Requisition(
      id: d.id,
      title: stringOf(m['title']),
      description: stringOf(m['description']),
      vendor: stringOf(m['vendor']),
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      budgetId: stringOf(m['budgetId']),
      budgetLineId: stringOf(m['budgetLineId']),
      budgetLineName: stringOf(m['budgetLineName']),
      status: enumByName(RequisitionStatus.values, m['status'], RequisitionStatus.submitted),
      requestedBy: stringOf(m['requestedBy']),
      requestedByName: stringOf(m['requestedByName']),
      createdAt: dateFrom(m['createdAt']),
      rejectionReason: m['rejectionReason'] as String?,
      transactionId: m['transactionId'] as String?,
    );
  }

  Future<void> submit(
    String churchId, {
    required String title,
    required String description,
    required String vendor,
    required int amount,
    required String budgetId,
    required String budgetLineId,
    required String budgetLineName,
    required String requesterName,
  }) =>
      queued(_col(churchId).doc().set({
        'title': title,
        'description': description,
        'vendor': vendor,
        'amount': amount,
        'budgetId': budgetId,
        'budgetLineId': budgetLineId,
        'budgetLineName': budgetLineName,
        'status': 'submitted',
        'requestedBy': _uid,
        'requestedByName': requesterName,
        'createdAt': FieldValue.serverTimestamp(),
      }));

  /// Approving reserves the amount against the budget line.
  Future<void> approve(String churchId, Requisition r, {required String approverName}) {
    final batch = _db.batch();
    batch.update(_col(churchId).doc(r.id), {
      'status': 'approved',
      'approvedBy': _uid,
      'approvedByName': approverName,
      'approvedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_line(churchId, r), {'committed': FieldValue.increment(r.amount)});
    return queued(batch.commit());
  }

  Future<void> reject(String churchId, Requisition r, String reason) => queued(_col(churchId).doc(r.id).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      }));

  /// Cancelling an approved request releases the reserved budget.
  Future<void> cancel(String churchId, Requisition r) {
    final batch = _db.batch();
    batch.update(_col(churchId).doc(r.id), {
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (r.status == RequisitionStatus.approved) {
      batch.update(_line(churchId, r), {'committed': FieldValue.increment(-r.amount)});
    }
    return queued(batch.commit());
  }

  Future<void> markOrdered(String churchId, Requisition r) => queued(_col(churchId).doc(r.id).update({
        'status': 'ordered',
        'orderedAt': FieldValue.serverTimestamp(),
      }));

  Future<void> markReceived(String churchId, Requisition r) => queued(_col(churchId).doc(r.id).update({
        'status': 'received',
        'receivedAt': FieldValue.serverTimestamp(),
      }));

  /// Pays the request: posts an expense to the ledger and releases the commitment.
  Future<void> markPaid(
    String churchId,
    Requisition r, {
    required Fund fund,
    required FinanceCategory category,
    required PaymentMethod method,
  }) {
    final batch = _db.batch();
    final txRef = _finance.stageTransaction(
      batch,
      churchId,
      FinanceTransaction(
        id: '',
        type: TxType.expense,
        amount: r.amount,
        fundId: fund.id,
        fundName: fund.name,
        categoryId: category.id,
        categoryName: category.name,
        method: method,
        date: DateTime.now(),
        description: 'Purchase: ${r.title}${r.vendor.isEmpty ? '' : ' (${r.vendor})'}',
        source: 'procurement',
        requisitionId: r.id,
        budgetId: r.budgetId,
        budgetLineId: r.budgetLineId,
      ),
      releaseCommitted: r.amount,
    );
    batch.update(_col(churchId).doc(r.id), {
      'status': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
      'paymentMethod': method.name,
      'transactionId': txRef.id,
    });
    return queued(batch.commit());
  }
}
