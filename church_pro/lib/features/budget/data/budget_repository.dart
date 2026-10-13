import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../data/firebase/firebase_helpers.dart';
import '../../finance/domain/finance_models.dart';
import '../domain/budget_models.dart';

/// churches/{c}/budgets/{id}              name, year, status, sharedWith, approval fields, aiSummary
/// churches/{c}/budgets/{id}/lines/{id}   name, type, planned, committed, actual
/// churches/{c}/budgets/{id}/comments/{id} discussion and step history
///
/// Journey: draft -> pending_approval (sent to the lead pastor) -> approved
/// (or changes_requested) -> active -> closed.
class BudgetRepository {
  BudgetRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _budgets(String c) =>
      _db.collection('churches').doc(c).collection('budgets');
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

  Budget _budget(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Budget(
      id: d.id,
      name: stringOf(m['name']),
      year: (m['year'] as num?)?.toInt() ?? 0,
      status: stringOf(m['status']).isEmpty ? 'draft' : stringOf(m['status']),
      sharedWith: ((m['sharedWith'] as List?) ?? const []).whereType<String>().toList(),
      submittedByName: m['submittedByName'] as String?,
      submittedAt: _date(m['submittedAt']),
      decidedByName: m['decidedByName'] as String?,
      decidedAt: _date(m['decidedAt']),
      decisionNote: stringOf(m['decisionNote']),
      aiSummary: stringOf(m['aiSummary']),
      aiSummaryAt: _date(m['aiSummaryAt']),
    );
  }

  List<Budget> _sorted(Iterable<Budget> items) => items.toList()
    ..sort((a, b) => a.year != b.year ? b.year.compareTo(a.year) : a.name.compareTo(b.name));

  /// Admin, accountant and lead pastor see every budget. Everyone else sees the
  /// budgets shared with them, plus the active budget.
  Stream<List<Budget>> watchBudgets(String churchId) async* {
    final uid = _uid;
    if (uid == null) {
      yield const <Budget>[];
      return;
    }
    final membership = await _db.collection('users').doc(uid).collection('memberships').doc(churchId).get();
    final role = membership.data()?['role'];

    if (const ['admin', 'accountant', 'leadPastor'].contains(role)) {
      yield* _budgets(churchId).snapshots().map((s) => _sorted(s.docs.map(_budget)));
    } else {
      yield* _merge(
        _budgets(churchId).where('sharedWith', arrayContains: uid).snapshots(),
        _budgets(churchId).where('status', isEqualTo: 'active').snapshots(),
      );
    }
  }

  Stream<List<Budget>> _merge(
      Stream<QuerySnapshot<Map<String, dynamic>>> a,
      Stream<QuerySnapshot<Map<String, dynamic>>> b,
      ) {
    late StreamController<List<Budget>> controller;
    var la = <Budget>[];
    var lb = <Budget>[];
    StreamSubscription<dynamic>? sa;
    StreamSubscription<dynamic>? sb;

    void emit() {
      final byId = {for (final x in [...la, ...lb]) x.id: x};
      controller.add(_sorted(byId.values));
    }

    controller = StreamController<List<Budget>>(
      onListen: () {
        sa = a.listen((s) {
          la = s.docs.map(_budget).toList();
          emit();
        }, onError: controller.addError);
        sb = b.listen((s) {
          lb = s.docs.map(_budget).toList();
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await sa?.cancel();
        await sb?.cancel();
      },
    );
    return controller.stream;
  }

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

  Stream<List<BudgetComment>> watchComments(String churchId, String budgetId) =>
      _budgets(churchId).doc(budgetId).collection('comments').snapshots().map(
            (s) => s.docs
            .map((d) => BudgetComment(
          id: d.id,
          authorUid: stringOf(d.data()['authorUid']),
          authorName: stringOf(d.data()['authorName']),
          authorRole: stringOf(d.data()['authorRole']),
          text: stringOf(d.data()['text']),
          isEvent: d.data()['kind'] == 'event',
          createdAt: dateFrom(d.data()['createdAt']),
        ))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );

  // ── Writing ──────────────────────────────────────────────────────────
  void _note(WriteBatch batch, String churchId, String budgetId, String text, String byName, String byRole,
      {bool event = true}) {
    batch.set(_budgets(churchId).doc(budgetId).collection('comments').doc(), {
      'authorUid': _uid,
      'authorName': byName,
      'authorRole': byRole,
      'text': text,
      'kind': event ? 'event' : 'comment',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> createBudget(
      String churchId, {
        required String name,
        required int year,
        required List<String> sharedWith,
        required String byName,
      }) async {
    final ref = _budgets(churchId).doc();
    await queued(ref.set({
      'name': name,
      'year': year,
      'status': 'draft',
      'sharedWith': sharedWith,
      'createdBy': _uid,
      'createdByName': byName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }));
    return ref.id;
  }

  Future<void> updateSharing(String churchId, String budgetId, List<String> sharedWith) =>
      queued(_budgets(churchId).doc(budgetId).update({
        'sharedWith': sharedWith,
        'updatedAt': FieldValue.serverTimestamp(),
      }));

  /// Admin or accountant sends the budget to the lead pastor.
  Future<void> submitForApproval(String churchId, String budgetId, {required String byName, required String byRole}) {
    final batch = _db.batch();
    batch.update(_budgets(churchId).doc(budgetId), {
      'status': 'pending_approval',
      'submittedBy': _uid,
      'submittedByName': byName,
      'submittedAt': FieldValue.serverTimestamp(),
      'decisionNote': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _note(batch, churchId, budgetId, 'Sent to the lead pastor for approval.', byName, byRole);
    return queued(batch.commit());
  }

  /// Lead pastor approves, or asks for changes with a note.
  Future<void> decide(
      String churchId,
      String budgetId, {
        required bool approve,
        required String byName,
        required String byRole,
        String note = '',
      }) {
    final batch = _db.batch();
    batch.update(_budgets(churchId).doc(budgetId), {
      'status': approve ? 'approved' : 'changes_requested',
      'decidedBy': _uid,
      'decidedByName': byName,
      'decidedAt': FieldValue.serverTimestamp(),
      'decisionNote': note,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _note(batch, churchId, budgetId, approve ? 'Approved.' : 'Asked for changes: $note', byName, byRole);
    return queued(batch.commit());
  }

  /// Makes [budgetId] the only active budget (the previous one is closed).
  Future<void> activate(
      String churchId,
      String budgetId, {
        String? previousActiveId,
        required String byName,
        required String byRole,
      }) {
    final batch = _db.batch();
    if (previousActiveId != null && previousActiveId != budgetId) {
      batch.update(_budgets(churchId).doc(previousActiveId), {
        'status': 'closed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(_budgets(churchId).doc(budgetId), {
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _note(batch, churchId, budgetId, 'Made the active budget.', byName, byRole);
    return queued(batch.commit());
  }

  Future<void> comment(String churchId, String budgetId,
      {required String text, required String byName, required String byRole}) {
    final batch = _db.batch();
    _note(batch, churchId, budgetId, text, byName, byRole, event: false);
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