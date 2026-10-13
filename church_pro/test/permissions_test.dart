import 'package:church_pro/core/constants/roles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin has every permission except approving budgets', () {
    for (final p in Permission.values) {
      expect(Permissions.can(ChurchRole.admin, p), p != Permission.approveBudget);
    }
  });

  test('only the lead pastor approves budgets', () {
    for (final r in ChurchRole.values) {
      expect(Permissions.can(r, Permission.approveBudget), r == ChurchRole.leadPastor);
    }
  });

  test('lead pastor reads reports but not the ledger or giving', () {
    expect(Permissions.can(ChurchRole.leadPastor, Permission.viewFinanceSummary), isTrue);
    expect(Permissions.can(ChurchRole.leadPastor, Permission.viewFinance), isFalse);
    expect(Permissions.can(ChurchRole.leadPastor, Permission.recordTransactions), isFalse);
  });

  test('accountant does the books but cannot approve purchases or budgets', () {
    expect(Permissions.can(ChurchRole.accountant, Permission.viewFinance), isTrue);
    expect(Permissions.can(ChurchRole.accountant, Permission.manageBudgets), isTrue);
    expect(Permissions.can(ChurchRole.accountant, Permission.approvePurchase), isFalse);
    expect(Permissions.can(ChurchRole.accountant, Permission.approveBudget), isFalse);
  });

  test('other pastors can read and comment on shared budgets but not prepare them', () {
    expect(Permissions.can(ChurchRole.pastor, Permission.viewBudgets), isTrue);
    expect(Permissions.can(ChurchRole.pastor, Permission.commentBudget), isTrue);
    expect(Permissions.can(ChurchRole.pastor, Permission.manageBudgets), isFalse);
    expect(Permissions.can(ChurchRole.pastor, Permission.viewFinance), isFalse);
  });

  test('staff can log work and request purchases but not see the ledger', () {
    expect(Permissions.can(ChurchRole.staff, Permission.logWork), isTrue);
    expect(Permissions.can(ChurchRole.staff, Permission.requestPurchase), isTrue);
    expect(Permissions.can(ChurchRole.staff, Permission.viewFinance), isFalse);
  });

  test('plain member has no staff permissions', () {
    for (final p in Permission.values) {
      expect(Permissions.can(ChurchRole.member, p), isFalse);
    }
  });

  test('only admins see the team work board and create logins', () {
    for (final r in ChurchRole.values) {
      expect(Permissions.can(r, Permission.viewTeamWork), r == ChurchRole.admin);
      expect(Permissions.can(r, Permission.manageUsers), r == ChurchRole.admin);
    }
  });

  test('admin cannot assign the admin role but can assign lead pastor', () {
    expect(Permissions.assignableRoles.contains(ChurchRole.admin), isFalse);
    expect(Permissions.assignableRoles.contains(ChurchRole.leadPastor), isTrue);
  });

  test('staff and accountant manage inventory; leaders only look', () {
    expect(Permissions.can(ChurchRole.staff, Permission.manageInventory), isTrue);
    expect(Permissions.can(ChurchRole.accountant, Permission.manageInventory), isTrue);
    expect(Permissions.can(ChurchRole.leader, Permission.viewInventory), isTrue);
    expect(Permissions.can(ChurchRole.leader, Permission.manageInventory), isFalse);
  });

  test('plain members do not chat or see the inventory until the admin allows it', () {
    expect(Permissions.can(ChurchRole.member, Permission.useChat), isFalse);
    expect(Permissions.can(ChurchRole.member, Permission.viewInventory), isFalse);
  });
}