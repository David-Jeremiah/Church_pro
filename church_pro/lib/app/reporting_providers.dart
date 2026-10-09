import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/finance/domain/finance_models.dart';
import 'providers.dart';

/// Every member's giving total for a year.
final givingTotalsProvider = StreamProvider.family<List<GivingTotal>, int>((ref, year) {
  final churchId = ref.watch(activeChurchIdProvider);
  if (churchId == null) return Stream.value(const <GivingTotal>[]);
  return ref.watch(financeRepositoryProvider).watchGivingTotals(churchId, year);
});

/// Church income and expenses, month by month, for a year.
final monthlyTotalsProvider = StreamProvider.family<List<MonthTotal>, int>((ref, year) {
  final churchId = ref.watch(activeChurchIdProvider);
  if (churchId == null) return Stream.value(const <MonthTotal>[]);
  return ref.watch(financeRepositoryProvider).watchMonthlyTotals(churchId, year);
});

/// All ledger entries for one member.
final memberTransactionsProvider = StreamProvider.family<List<FinanceTransaction>, String>((ref, memberId) {
  final churchId = ref.watch(activeChurchIdProvider);
  if (churchId == null) return Stream.value(const <FinanceTransaction>[]);
  return ref.watch(financeRepositoryProvider).watchMemberTransactions(churchId, memberId);
});