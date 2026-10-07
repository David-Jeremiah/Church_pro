class Church {
  const Church({
    required this.id,
    required this.name,
    this.currency = 'UGX',
    this.status = 'active',
    this.country = '',
    this.adminEmail = '',
    this.blockOverBudget = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String currency;

  /// 'active' or 'suspended' (set by the platform admin).
  final String status;
  final String country;
  final String adminEmail;

  /// When true, purchase requests above the available budget cannot be submitted or approved.
  final bool blockOverBudget;
  final DateTime? createdAt;

  bool get isActive => status == 'active';
}
