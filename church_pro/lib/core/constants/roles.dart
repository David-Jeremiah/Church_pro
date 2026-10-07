/// Roles a user can hold inside ONE church. Keep in sync with
/// docs/03-roles-permissions-matrix.md and firestore.rules.
///
/// The platform owner (system admin) is NOT a church role: that person is
/// listed in the `platformAdmins` collection and uses the platform console.
enum ChurchRole {
  admin,
  accountant,
  pastor,
  leader,
  staff,
  member;

  String get label => name[0].toUpperCase() + name.substring(1);

  static ChurchRole fromName(String? value) => ChurchRole.values.firstWhere(
        (r) => r.name == value,
        orElse: () => ChurchRole.member,
      );
}

enum Permission {
  viewMembers,
  manageMembers,
  markAttendance,
  manageServices,
  manageEvents,
  viewFinance, // ledger, funds, overview, budgets
  recordTransactions,
  manageBudgets,
  requestPurchase,
  approvePurchase,
  processPurchase, // order, receive, pay
  logWork, // clock in/out with office / home / field
  viewTeamWork,
  manageUsers, // create logins for the church team
}

/// UI-level permission checks. These only hide UI; firestore.rules enforces
/// the same matrix on the server.
///
/// Accounting is done by the admin, or by the accountant when the church has one.
class Permissions {
  static const Map<ChurchRole, Set<Permission>> _matrix = {
    ChurchRole.admin: {...Permission.values},
    ChurchRole.accountant: {
      Permission.viewMembers,
      Permission.viewFinance,
      Permission.recordTransactions,
      Permission.manageBudgets,
      Permission.requestPurchase,
      Permission.processPurchase,
      Permission.logWork,
    },
    ChurchRole.pastor: {
      Permission.viewMembers,
      Permission.manageMembers,
      Permission.markAttendance,
      Permission.manageServices,
      Permission.manageEvents,
      Permission.requestPurchase,
      Permission.logWork,
    },
    ChurchRole.leader: {
      Permission.viewMembers,
      Permission.markAttendance,
      Permission.requestPurchase,
    },
    ChurchRole.staff: {
      Permission.viewMembers,
      Permission.manageMembers,
      Permission.markAttendance,
      Permission.manageServices,
      Permission.manageEvents,
      Permission.requestPurchase,
      Permission.logWork,
    },
    ChurchRole.member: <Permission>{},
  };

  static bool can(ChurchRole role, Permission permission) => _matrix[role]!.contains(permission);

  /// Roles a church admin may create logins for (never another admin).
  static const assignableRoles = [
    ChurchRole.accountant,
    ChurchRole.pastor,
    ChurchRole.staff,
    ChurchRole.leader,
    ChurchRole.member,
  ];
}
