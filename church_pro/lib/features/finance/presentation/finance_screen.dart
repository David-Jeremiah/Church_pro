import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../budget/presentation/budgets_tab.dart';
import '../../procurement/presentation/purchases_tab.dart';
import 'giving_tab.dart';
import 'ledger_tab.dart';
import 'overview_tab.dart';
import 'reports_tab.dart';

/// Finance hub. Admin and accountant see everything (accounting is done by the
/// admin, or by the accountant when the church has one). Other staff only see
/// the Purchases tab to request items and follow their requests.
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  bool _seedChecked = false;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    final viewFinance = Permissions.can(role, Permission.viewFinance);
    final canRequest = Permissions.can(role, Permission.requestPurchase);

    // First time a finance user opens a new church: create funds and categories.
    if (Permissions.can(role, Permission.recordTransactions) && !_seedChecked) {
      final funds = ref.watch(fundsProvider);
      if (funds.hasValue) {
        _seedChecked = true;
        final churchId = ref.read(activeChurchIdProvider);
        if (funds.value!.isEmpty && churchId != null) {
          WidgetsBinding.instance.addPostFrameCallback(
                (_) => ref.read(financeRepositoryProvider).ensureDefaults(churchId),
          );
        }
      }
    }

    final tabs = <(String, Widget)>[
      if (viewFinance) ('Overview', const OverviewTab()),
      if (viewFinance) ('Ledger', const LedgerTab()),
      if (viewFinance) ('Giving', const GivingTab()),
      if (viewFinance) ('Reports', const ReportsTab()),
      if (viewFinance) ('Budgets', const BudgetsTab()),
      if (canRequest) ('Purchases', const PurchasesTab()),
    ];
    if (tabs.isEmpty) return const Center(child: Text('You do not have access to this section'));

    return DefaultTabController(
      key: ValueKey(tabs.length),
      length: tabs.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in tabs) Tab(text: t.$1)],
          ),
          Expanded(child: TabBarView(children: [for (final t in tabs) t.$2])),
        ],
      ),
    );
  }
}