import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/inventory/data/inventory_repository.dart';
import '../features/inventory/domain/inventory_models.dart';
import 'providers.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) => InventoryRepository());

final inventoryItemsProvider = StreamProvider<List<InventoryItem>>((ref) {
  final churchId = ref.watch(activeChurchIdProvider);
  if (churchId == null) return Stream.value(const <InventoryItem>[]);
  return ref.watch(inventoryRepositoryProvider).watchItems(churchId);
});

final stockMovesProvider = StreamProvider.family<List<StockMove>, String>((ref, itemId) {
  final churchId = ref.watch(activeChurchIdProvider);
  if (churchId == null) return Stream.value(const <StockMove>[]);
  return ref.watch(inventoryRepositoryProvider).watchMoves(churchId, itemId);
});