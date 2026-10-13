import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/member.dart';

String _statusLabel(MembershipStatus s) => switch (s) {
  MembershipStatus.visitor => 'Visitor',
  MembershipStatus.newConvert => 'New convert',
  MembershipStatus.member => 'Member',
  MembershipStatus.inactive => 'Inactive',
};

/// One member's details, with shortcuts to edit them and to see their giving.
class MemberProfileScreen extends ConsumerWidget {
  const MemberProfileScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool can(Permission p) => ref.watch(canProvider(p));

    final membersAsync = ref.watch(membersProvider);
    final members = membersAsync.value ?? const <Member>[];
    final member = members.where((m) => m.id == memberId).firstOrNull;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);

    if (member == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Member')),
        body: Center(
          child: membersAsync.isLoading ? const CircularProgressIndicator() : const Text('This member could not be found.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(member.fullName),
        actions: [
          if (can(Permission.manageMembers))
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/members/form', extra: member),
            ),
        ],
      ),
      body: ContentWidth(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      member.firstName.isEmpty ? '?' : member.firstName[0].toUpperCase(),
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(member.fullName, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(_statusLabel(member.status), style: TextStyle(color: muted)),
                ],
              ),
            ),
            const SectionTitle('Contact'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: Text(member.phone.isEmpty ? 'No phone number' : member.phone),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: Text(member.email.isEmpty ? 'No email' : member.email),
                  ),
                  if (member.userUid != null) ...[
                    const Divider(height: 1),
                    const ListTile(
                      leading: Icon(Icons.verified_user_outlined),
                      title: Text('Has an app account'),
                    ),
                  ],
                ],
              ),
            ),
            if (can(Permission.recordTransactions) || can(Permission.viewFinance)) ...[
              const SectionTitle('Giving'),
              Card(
                child: Column(
                  children: [
                    if (can(Permission.recordTransactions))
                      ListTile(
                        leading: const Icon(Icons.volunteer_activism),
                        title: const Text('Record a tithe'),
                        trailing: Icon(Icons.chevron_right, color: muted),
                        onTap: () => context.push('/finance/tithes?member=${member.id}'),
                      ),
                    if (can(Permission.recordTransactions) && can(Permission.viewFinance)) const Divider(height: 1),
                    if (can(Permission.viewFinance))
                      ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: const Text('Giving statement'),
                        trailing: Icon(Icons.chevron_right, color: muted),
                        onTap: () => context.push('/finance/member/${member.id}'),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}