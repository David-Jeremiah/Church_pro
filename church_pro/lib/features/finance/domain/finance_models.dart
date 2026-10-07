enum TxType { income, expense }

enum PaymentMethod {
  cash('Cash'),
  mtnMomo('MTN MoMo'),
  airtelMoney('Airtel Money'),
  bank('Bank'),
  cheque('Cheque');

  const PaymentMethod(this.label);
  final String label;
}

class Fund {
  const Fund({
    required this.id,
    required this.name,
    this.restricted = false,
    this.balance = 0,
    this.active = true,
  });

  final String id;
  final String name;

  /// Restricted funds may only be spent for their stated purpose.
  final bool restricted;
  final int balance;
  final bool active;
}

class FinanceCategory {
  const FinanceCategory({required this.id, required this.name, required this.type});

  final String id;
  final String name;
  final TxType type;
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.fundId,
    required this.fundName,
    required this.categoryId,
    required this.categoryName,
    required this.method,
    required this.date,
    this.description = '',
    this.memberId,
    this.memberName,
    this.source = 'manual',
    this.requisitionId,
    this.budgetId,
    this.budgetLineId,
    this.voided = false,
  });

  final String id;
  final TxType type;

  /// Integer in the smallest currency unit.
  final int amount;
  final String fundId;
  final String fundName;
  final String categoryId;
  final String categoryName;
  final PaymentMethod method;
  final DateTime date;
  final String description;
  final String? memberId;
  final String? memberName;

  /// 'manual' or 'procurement'.
  final String source;
  final String? requisitionId;
  final String? budgetId;
  final String? budgetLineId;
  final bool voided;

  int get signedAmount => type == TxType.income ? amount : -amount;
}
