import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../data/firebase/firebase_helpers.dart';
import '../domain/inventory_models.dart';

/// churches/{c}/inventoryItems/{id}          the item and how many are in stock
/// churches/{c}/inventoryItems/{id}/moves    every change to the stock, with who and why
class InventoryRepository {
  InventoryRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _items(String c) =>
      _db.collection('churches').doc(c).collection('inventoryItems');
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<InventoryItem>> watchItems(String churchId) => _items(churchId).snapshots().map(
        (s) => s.docs
            .map((d) => InventoryItem(
                  id: d.id,
                  name: stringOf(d.data()['name']),
                  category: stringOf(d.data()['category']),
                  unit: stringOf(d.data()['unit']),
                  quantity: (d.data()['quantity'] as num?)?.toInt() ?? 0,
                  minLevel: (d.data()['minLevel'] as num?)?.toInt() ?? 0,
                  location: stringOf(d.data()['location']),
                  notes: stringOf(d.data()['notes']),
                  custodian: stringOf(d.data()['custodian']),
                  active: d.data()['active'] != false,
                ))
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      );

  Stream<List<StockMove>> watchMoves(String churchId, String itemId) =>
      _items(churchId).doc(itemId).collection('moves').snapshots().map(
            (s) => s.docs
                .map((d) => StockMove(
                      id: d.id,
                      kind: enumByName(StockKind.values, d.data()['kind'], StockKind.counted),
                      quantity: (d.data()['quantity'] as num?)?.toInt() ?? 0,
                      delta: (d.data()['delta'] as num?)?.toInt() ?? 0,
                      balanceAfter: (d.data()['balanceAfter'] as num?)?.toInt() ?? 0,
                      reason: stringOf(d.data()['reason']),
                      note: stringOf(d.data()['note']),
                      byName: stringOf(d.data()['byName']),
                      createdAt: dateFrom(d.data()['createdAt']),
                    ))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
          );

  void _stageMove(
    WriteBatch batch,
    String churchId,
    String itemId, {
    required StockKind kind,
    required int quantity,
    required int delta,
    required int balanceAfter,
    required String reason,
    required String note,
    required String byName,
  }) {
    batch.set(_items(churchId).doc(itemId).collection('moves').doc(), {
      'kind': kind.name,
      'quantity': quantity,
      'delta': delta,
      'balanceAfter': balanceAfter,
      'reason': reason,
      'note': note,
      'byUid': _uid,
      'byName': byName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> addItem(
    String churchId, {
    required String name,
    required String category,
    required String unit,
    required int quantity,
    required int minLevel,
    required String location,
    required String notes,
    required String byName,
  }) async {
    final ref = _items(churchId).doc();
    final batch = _db.batch();
    batch.set(ref, {
      'name': name,
      'category': category,
      'unit': unit,
      'quantity': quantity,
      'minLevel': minLevel,
      'location': location,
      'notes': notes,
      'custodian': '',
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (quantity > 0) {
      _stageMove(batch, churchId, ref.id,
          kind: StockKind.added, quantity: quantity, delta: quantity, balanceAfter: quantity, reason: 'Opening stock', note: '', byName: byName);
    }
    await queued(batch.commit());
    return ref.id;
  }

  Future<void> updateItem(
    String churchId,
    String itemId, {
    required String name,
    required String category,
    required String unit,
    required int minLevel,
    required String location,
    required String notes,
    required bool active,
  }) =>
      queued(_items(churchId).doc(itemId).update({
        'name': name,
        'category': category,
        'unit': unit,
        'minLevel': minLevel,
        'location': location,
        'notes': notes,
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      }));

  /// Stock in, stock out or a count. Throws if you try to take out more than is there.
  Future<void> move(
    String churchId,
    InventoryItem item, {
    required StockKind kind,
    required int quantity,
    required String reason,
    required String note,
    required String byName,
    String? custodian,
  }) {
    if (quantity < 0 || (kind != StockKind.counted && quantity == 0)) throw Exception('Enter a number greater than zero.');
    if (kind == StockKind.taken && quantity > item.quantity) {
      throw Exception('Only ${item.quantity} ${item.unit} in stock.');
    }
    final delta = switch (kind) {
      StockKind.added => quantity,
      StockKind.taken => -quantity,
      StockKind.counted => quantity - item.quantity,
    };
    final newBalance = item.quantity + delta;

    final batch = _db.batch();
    batch.update(_items(churchId).doc(item.id), {
      'quantity': kind == StockKind.counted ? quantity : FieldValue.increment(delta),
      if (custodian != null) 'custodian': custodian,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _stageMove(batch, churchId, item.id,
        kind: kind, quantity: quantity, delta: delta, balanceAfter: newBalance, reason: reason, note: note, byName: byName);
    return queued(batch.commit());
  }
}
