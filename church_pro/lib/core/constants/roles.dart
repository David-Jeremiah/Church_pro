/// Roles a user can hold inside ONE church. Keep in sync with
/// docs/03-roles-permissions-matrix.md and firestore.rules.
///
/// The platform owner (system admin) is NOT a church role: that person is
/// listed in the `platformAdmins` collection and uses the platform console.
enum ChurchRole {
  admin,
  accountant,
  leadPastor,
  pastor,
  leader,
  staff,
  member;

  String get label => switch (this) {
    ChurchRole.leadPastor => 'Lead pastor',
    _ => name[0].toUpperCase() + name.substring(1),
  };

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
  viewPlanning, // the calendar and the Sunday plans
  viewInventory,
  manageInventory, // add items, take stock in and out
  useChat,
  viewFinance, // ledger, funds, overview, giving
  viewFinanceSummary, // yearly reports only (lead pastor)
  recordTransactions,
  manageBudgets, // create, edit and send budgets for approval
  viewBudgets, // budgets shared with you, and the active budget
  commentBudget,
  approveBudget, // lead pastor only
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
/// Budgets are prepared by the admin/accountant and approved by the lead pastor.
class Permissions {
  static final Map<ChurchRole, Set<Permission>> _matrix = {
    // The admin prepares budgets and sends them on; approval belongs to the lead pastor.
    ChurchRole.admin: Permission.values.where((p) => p != Permission.approveBudget).toSet(),
    ChurchRole.accountant: {
      Permission.viewMembers,
      Permission.viewFinance,
      Permission.recordTransactions,
      Permission.manageBudgets,
      Permission.viewBudgets,
      Permission.commentBudget,
      Permission.viewPlanning,
      Permission.viewInventory,
      Permission.manageInventory,
      Permission.useChat,
      Permission.requestPurchase,
      Permission.processPurchase,
      Permission.logWork,
    },
    ChurchRole.leadPastor: {
      Permission.viewMembers,
      Permission.manageMembers,
      Permission.markAttendance,
      Permission.manageServices,
      Permission.manageEvents,
      Permission.viewFinanceSummary,
      Permission.viewBudgets,
      Permission.commentBudget,
      Permission.approveBudget,
      Permission.viewPlanning,
      Permission.viewInventory,
      Permission.useChat,
      Permission.requestPurchase,
      Permission.logWork,
    },
    ChurchRole.pastor: {
      Permission.viewMembers,
      Permission.manageMembers,
      Permission.markAttendance,
      Permission.manageServices,
      Permission.manageEvents,
      Permission.viewBudgets,
      Permission.commentBudget,
      Permission.viewPlanning,
      Permission.viewInventory,
      Permission.useChat,
      Permission.requestPurchase,
      Permission.logWork,
    },
    ChurchRole.leader: {
      Permission.viewMembers,
      Permission.markAttendance,
      Permission.viewBudgets,
      Permission.commentBudget,
      Permission.viewPlanning,
      Permission.viewInventory,
      Permission.useChat,
      Permission.requestPurchase,
    },
    ChurchRole.staff: {
      Permission.viewMembers,
      Permission.manageMembers,
      Permission.markAttendance,
      Permission.manageServices,
      Permission.manageEvents,
      Permission.viewBudgets,
      Permission.commentBudget,
      Permission.viewPlanning,
      Permission.viewInventory,
      Permission.manageInventory,
      Permission.useChat,
      Permission.requestPurchase,
      Permission.logWork,
    },
    ChurchRole.member: <Permission>{},
  };

  static bool can(ChurchRole role, Permission permission) => _matrix[role]!.contains(permission);

  /// Roles a church admin may create logins for (never another admin).
  static const assignableRoles = [
    ChurchRole.accountant,
    ChurchRole.leadPastor,
    ChurchRole.pastor,
    ChurchRole.staff,
    ChurchRole.leader,
    ChurchRole.member,
  ];
}