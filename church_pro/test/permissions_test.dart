import 'package:church_pro/core/constants/roles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin has every permission', () {
    for (final p in Permission.values) {
      expect(Permissions.can(ChurchRole.admin, p), isTrue);
    }
  });

  test('accountant does the books but cannot approve purchases', () {
    expect(Permissions.can(ChurchRole.accountant, Permission.viewFinance), isTrue);
    expect(Permissions.can(ChurchRole.accountant, Permission.recordTransactions), isTrue);
    expect(Permissions.can(ChurchRole.accountant, Permission.processPurchase), isTrue);
    expect(Permissions.can(ChurchRole.accountant, Permission.approvePurchase), isFalse);
    expect(Permissions.can(ChurchRole.accountant, Permission.manageUsers), isFalse);
  });

  test('staff can log work and request purchases but not see the ledger', () {
    expect(Permissions.can(ChurchRole.staff, Permission.logWork), isTrue);
    expect(Permissions.can(ChurchRole.staff, Permission.requestPurchase), isTrue);
    expect(Permissions.can(ChurchRole.staff, Permission.viewFinance), isFalse);
    expect(Permissions.can(ChurchRole.staff, Permission.viewTeamWork), isFalse);
  });

  test('leader marks attendance but does not clock in', () {
    expect(Permissions.can(ChurchRole.leader, Permission.markAttendance), isTrue);
    expect(Permissions.can(ChurchRole.leader, Permission.logWork), isFalse);
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

  test('admin cannot assign the admin role', () {
    expect(Permissions.assignableRoles.contains(ChurchRole.admin), isFalse);
  });
}
