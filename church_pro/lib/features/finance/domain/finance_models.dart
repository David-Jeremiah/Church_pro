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
    this.serviceId,
    this.serviceTitle,
    this.receiptNo,
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

  /// Who gave (income only). Lets us total a person's giving for the year.
  final String? memberId;
  final String? memberName;

  /// The service this offertory was collected at (income only).
  final String? serviceId;
  final String? serviceTitle;

  /// Set once an official receipt has been issued, e.g. R-2026-00012.
  final String? receiptNo;

  /// 'manual' or 'procurement'.
  final String source;
  final String? requisitionId;
  final String? budgetId;
  final String? budgetLineId;
  final bool voided;

  int get signedAmount => type == TxType.income ? amount : -amount;
}

/// One member's giving for one year (kept up to date with every ledger entry).
class GivingTotal {
  const GivingTotal({
    required this.memberId,
    required this.memberName,
    required this.year,
    required this.total,
    required this.count,
    required this.byCategory,
  });

  final String memberId;
  final String memberName;
  final int year;
  final int total;
  final int count;

  /// category id -> amount (for example tithe, offering)
  final Map<String, int> byCategory;

  int of(String categoryId) => byCategory[categoryId] ?? 0;
}

/// Church-wide income and expenses for one month.
class MonthTotal {
  const MonthTotal({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
    required this.incomeByCategory,
    required this.expenseByCategory,
  });

  final int year;
  final int month;
  final int income;
  final int expense;
  final Map<String, int> incomeByCategory;
  final Map<String, int> expenseByCategory;
}