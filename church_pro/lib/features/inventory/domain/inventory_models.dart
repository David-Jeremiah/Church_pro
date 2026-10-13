class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    this.minLevel = 0,
    this.location = '',
    this.notes = '',
    this.custodian = '',
    this.active = true,
  });

  final String id;
  final String name;
  final String category;

  /// For example pieces, boxes, litres.
  final String unit;
  final int quantity;

  /// Warn when the stock falls to this level or below (0 = no warning).
  final int minLevel;
  final String location;
  final String notes;

  /// Who currently has it, when it has been lent out.
  final String custodian;
  final bool active;

  bool get isLow => active && minLevel > 0 && quantity <= minLevel;
  bool get isOut => active && quantity <= 0;
  bool get isLentOut => active && custodian.trim().isNotEmpty;
}

enum StockKind {
  added('Stock added'),
  taken('Taken out'),
  counted('Stock count');

  const StockKind(this.label);
  final String label;
}

class StockMove {
  const StockMove({
    required this.id,
    required this.kind,
    required this.quantity,
    required this.delta,
    required this.balanceAfter,
    required this.reason,
    required this.note,
    required this.byName,
    required this.createdAt,
  });

  final String id;
  final StockKind kind;
  final int quantity;

  /// Change to the stock: positive when added, negative when taken.
  final int delta;
  final int balanceAfter;
  final String reason;
  final String note;
  final String byName;
  final DateTime createdAt;
}

const inventoryCategories = [
  'Sound and media',
  'Musical instruments',
  'Furniture',
  'Kitchen',
  'Cleaning',
  'Stationery',
  'Vehicles and tools',
  'Other',
];

const stockReasons = {
  StockKind.added: ['Purchased', 'Donated', 'Returned', 'Other'],
  StockKind.taken: ['Used', 'Lent out', 'Damaged', 'Lost', 'Other'],
  StockKind.counted: ['Stock count'],
};