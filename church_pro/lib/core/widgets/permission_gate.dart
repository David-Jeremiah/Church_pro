import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../constants/roles.dart';

/// Shows [child] only if the current role has [permission].
/// Pass `fallback: const SizedBox.shrink()` to hide silently (e.g. buttons).
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  final Permission permission;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(canProvider(permission))) return child;
    return fallback ?? const _NoAccess();
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, size: 40),
        SizedBox(height: 8),
        Text('You do not have access to this section'),
      ],
    ),
  );
}