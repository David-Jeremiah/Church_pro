import 'package:flutter/material.dart';

import 'roles.dart';

/// Parts of the app whose visibility the church admin can change.
/// (Money rules such as the ledger, giving and approvals are fixed.)
enum AccessModule {
  people('People directory', 'The member list and member profiles', Icons.people_outline, Permission.viewMembers),
  planning('Planning calendar', 'The calendar, Sunday plans and bookings', Icons.calendar_month_outlined, Permission.viewPlanning),
  inventory('Inventory', 'Equipment, supplies and stock', Icons.inventory_2_outlined, Permission.viewInventory),
  chat('Messages', 'Church chat and direct messages', Icons.forum_outlined, Permission.useChat),
  reports(
    'Finance reports',
    'Yearly income against expenses. It never shows who gave what.',
    Icons.bar_chart,
    Permission.viewFinanceSummary,
  ),
  teamWork('Team work board', 'Who is working from the office or from home', Icons.groups_outlined, Permission.viewTeamWork);

  const AccessModule(this.label, this.description, this.icon, this.permission);

  final String label;
  final String description;
  final IconData icon;
  final Permission permission;

  static AccessModule? forPermission(Permission p) {
    for (final m in values) {
      if (m.permission == p) return m;
    }
    return null;
  }

  /// Roles that can see it before the admin changes anything.
  Set<ChurchRole> get defaultRoles => {
    for (final r in ChurchRole.values)
      if (Permissions.can(r, permission)) r,
  };
}