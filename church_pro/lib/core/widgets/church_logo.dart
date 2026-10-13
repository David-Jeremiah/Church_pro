import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'ui_kit.dart';

/// The church's own logo, or its first letter until a logo is added.
class ChurchLogo extends ConsumerWidget {
  const ChurchLogo({super.key, this.size = 36, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logo = ref.watch(churchProfileProvider).value?.logo;
    final name = ref.watch(activeMembershipProvider)?.churchName ?? '';
    final fallback = InitialAvatar(name, size: size, onDark: onDark);
    if (logo == null || logo.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.memory(
        logo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}